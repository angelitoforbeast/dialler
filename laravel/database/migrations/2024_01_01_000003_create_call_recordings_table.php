<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('call_recordings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->string('caller');
            $table->string('callee');
            $table->integer('duration')->default(0);
            $table->string('status')->default('completed');
            $table->string('recording_file')->nullable();
            $table->string('recording_path')->nullable();
            $table->bigInteger('file_size')->default(0);
            $table->string('uniqueid')->nullable()->unique();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('call_recordings');
    }
};
