<?php

namespace App\Http\Controllers;

use App\Models\CallRecording;
use App\Models\User;
use App\Models\Shipment;
use Illuminate\Http\Request;

class DashboardController extends Controller
{
    public function index()
    {
        $recordings = CallRecording::with('user:id,name,sip_account')
            ->orderBy('created_at', 'desc')
            ->paginate(20);

        $stats = [
            'total_recordings' => CallRecording::count(),
            'total_agents'     => User::count(),
            'total_shipments'  => Shipment::count(),
            'total_duration'   => CallRecording::sum('duration'),
        ];

        return view('dashboard', compact('recordings', 'stats'));
    }
}
