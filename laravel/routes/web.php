<?php

use App\Http\Controllers\DashboardController;
use App\Http\Controllers\RecordingController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
*/

Route::get('/', [DashboardController::class, 'index'])->name('dashboard');
Route::get('/recordings/{id}/play', [RecordingController::class, 'play'])->name('recordings.play');
