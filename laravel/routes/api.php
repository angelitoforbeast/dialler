<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\ShipmentController;
use App\Http\Controllers\RecordingController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
*/

// Public routes
Route::post('/login', [AuthController::class, 'login']);

// Webhook from Asterisk (no auth required - internal only)
Route::post('/webhook/call-ended', [RecordingController::class, 'webhookCallEnded']);

// Protected routes (require Sanctum token)
Route::middleware('auth:sanctum')->group(function () {
    // Auth
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/user', [AuthController::class, 'user']);

    // Shipments
    Route::get('/shipments', [ShipmentController::class, 'index']);
    Route::get('/shipments/{id}', [ShipmentController::class, 'show']);

    // Recordings
    Route::get('/recordings', [RecordingController::class, 'index']);
    Route::get('/recordings/all', [RecordingController::class, 'all']);
    Route::post('/upload-recording', [RecordingController::class, 'upload']);
    Route::get('/recordings/{id}/play', [RecordingController::class, 'play']);
});
