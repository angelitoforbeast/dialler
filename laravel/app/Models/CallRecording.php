<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class CallRecording extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'caller',
        'callee',
        'duration',
        'status',
        'recording_file',
        'recording_path',
        'file_size',
        'uniqueid',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
