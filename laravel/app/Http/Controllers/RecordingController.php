<?php

namespace App\Http\Controllers;

use App\Models\CallRecording;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class RecordingController extends Controller
{
    /**
     * GET /api/recordings
     * Returns list of recordings for the authenticated user
     */
    public function index(Request $request)
    {
        $user = $request->user();

        $recordings = CallRecording::where('user_id', $user->id)
            ->orWhere('caller', $user->sip_account)
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json([
            'success'    => true,
            'recordings' => $recordings,
        ]);
    }

    /**
     * GET /api/recordings/all
     * Returns all recordings (admin/dashboard)
     */
    public function all()
    {
        $recordings = CallRecording::with('user:id,name,sip_account')
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json([
            'success'    => true,
            'recordings' => $recordings,
        ]);
    }

    /**
     * POST /api/upload-recording
     * Accepts recording file, updates database
     */
    public function upload(Request $request)
    {
        $request->validate([
            'recording' => 'required|file|mimes:wav,mp3,ogg|max:102400',
            'caller'    => 'nullable|string',
            'callee'    => 'nullable|string',
            'duration'  => 'nullable|integer',
            'uniqueid'  => 'nullable|string',
        ]);

        $file = $request->file('recording');
        $filename = $file->getClientOriginalName();
        $path = $file->store('recordings', 'public');

        // Find user by caller SIP account
        $user = null;
        if ($request->caller) {
            $user = User::where('sip_account', $request->caller)->first();
        }

        $recording = CallRecording::updateOrCreate(
            ['uniqueid' => $request->uniqueid],
            [
                'user_id'        => $user?->id,
                'caller'         => $request->caller ?? 'unknown',
                'callee'         => $request->callee ?? 'unknown',
                'duration'       => $request->duration ?? 0,
                'status'         => 'completed',
                'recording_file' => $filename,
                'recording_path' => $path,
                'file_size'      => $file->getSize(),
            ]
        );

        return response()->json([
            'success'   => true,
            'message'   => 'Recording uploaded successfully.',
            'recording' => $recording,
        ]);
    }

    /**
     * POST /api/webhook/call-ended
     * Called by Asterisk after each call ends
     */
    public function webhookCallEnded(Request $request)
    {
        $data = $request->all();

        // Find user by caller SIP account
        $user = User::where('sip_account', $data['caller'] ?? '')->first();

        // Extract just the filename from the full path
        $recordingFile = $data['recording_file'] ?? '';
        $filename = basename($recordingFile);

        $recording = CallRecording::updateOrCreate(
            ['uniqueid' => $data['uniqueid'] ?? null],
            [
                'user_id'        => $user?->id,
                'caller'         => $data['caller'] ?? 'unknown',
                'callee'         => $data['callee'] ?? 'unknown',
                'duration'       => intval($data['duration'] ?? 0),
                'status'         => $data['status'] ?? 'completed',
                'recording_file' => $filename,
                'recording_path' => $recordingFile,
                'file_size'      => file_exists($recordingFile) ? filesize($recordingFile) : 0,
            ]
        );

        return response()->json([
            'success'   => true,
            'message'   => 'Call recording logged.',
            'recording' => $recording,
        ]);
    }

    /**
     * GET /api/recordings/{id}/play
     * Stream the recording file
     */
    public function play($id)
    {
        $recording = CallRecording::findOrFail($id);

        // Try Asterisk recording path first
        if ($recording->recording_path && file_exists($recording->recording_path)) {
            return response()->file($recording->recording_path, [
                'Content-Type' => 'audio/wav',
            ]);
        }

        // Try Laravel storage
        if ($recording->recording_path && Storage::disk('public')->exists($recording->recording_path)) {
            return response()->file(Storage::disk('public')->path($recording->recording_path), [
                'Content-Type' => 'audio/wav',
            ]);
        }

        return response()->json(['error' => 'Recording file not found.'], 404);
    }
}
