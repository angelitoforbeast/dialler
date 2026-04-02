<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Call Center Dashboard</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css" rel="stylesheet">
    <style>
        body {
            background-color: #f4f6f9;
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        }
        .navbar {
            background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
        }
        .stat-card {
            background: white;
            border-radius: 12px;
            padding: 24px;
            box-shadow: 0 2px 12px rgba(0,0,0,0.08);
            transition: transform 0.2s;
        }
        .stat-card:hover {
            transform: translateY(-2px);
        }
        .stat-card .icon {
            width: 56px;
            height: 56px;
            border-radius: 12px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 24px;
        }
        .stat-card .number {
            font-size: 28px;
            font-weight: 700;
            color: #1e3c72;
        }
        .stat-card .label {
            color: #6c757d;
            font-size: 14px;
        }
        .table-card {
            background: white;
            border-radius: 12px;
            box-shadow: 0 2px 12px rgba(0,0,0,0.08);
            overflow: hidden;
        }
        .table-card .card-header {
            background: white;
            border-bottom: 2px solid #f0f0f0;
            padding: 20px 24px;
        }
        .table th {
            background: #f8f9fa;
            font-weight: 600;
            font-size: 13px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            color: #6c757d;
        }
        .badge-status {
            padding: 6px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
        }
        audio {
            height: 36px;
            width: 100%;
            max-width: 280px;
        }
        .empty-state {
            padding: 60px 20px;
            text-align: center;
            color: #adb5bd;
        }
        .empty-state i {
            font-size: 48px;
            margin-bottom: 16px;
        }
    </style>
</head>
<body>
    <!-- Navbar -->
    <nav class="navbar navbar-dark py-3">
        <div class="container">
            <a class="navbar-brand d-flex align-items-center" href="/">
                <i class="fas fa-headset me-2"></i>
                <strong>Call Center Dashboard</strong>
            </a>
            <span class="text-white-50">
                <i class="fas fa-server me-1"></i> Asterisk PBX Monitor
            </span>
        </div>
    </nav>

    <div class="container py-4">
        <!-- Stats Row -->
        <div class="row g-4 mb-4">
            <div class="col-md-3">
                <div class="stat-card">
                    <div class="d-flex align-items-center">
                        <div class="icon bg-primary bg-opacity-10 text-primary me-3">
                            <i class="fas fa-phone"></i>
                        </div>
                        <div>
                            <div class="number">{{ $stats['total_recordings'] }}</div>
                            <div class="label">Total Calls</div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="stat-card">
                    <div class="d-flex align-items-center">
                        <div class="icon bg-success bg-opacity-10 text-success me-3">
                            <i class="fas fa-users"></i>
                        </div>
                        <div>
                            <div class="number">{{ $stats['total_agents'] }}</div>
                            <div class="label">Active Agents</div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="stat-card">
                    <div class="d-flex align-items-center">
                        <div class="icon bg-warning bg-opacity-10 text-warning me-3">
                            <i class="fas fa-box"></i>
                        </div>
                        <div>
                            <div class="number">{{ $stats['total_shipments'] }}</div>
                            <div class="label">Shipments</div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="stat-card">
                    <div class="d-flex align-items-center">
                        <div class="icon bg-info bg-opacity-10 text-info me-3">
                            <i class="fas fa-clock"></i>
                        </div>
                        <div>
                            <div class="number">{{ gmdate('H:i:s', $stats['total_duration']) }}</div>
                            <div class="label">Total Duration</div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Recordings Table -->
        <div class="table-card">
            <div class="card-header d-flex justify-content-between align-items-center">
                <h5 class="mb-0">
                    <i class="fas fa-microphone me-2 text-primary"></i>
                    Call Recordings
                </h5>
                <span class="text-muted">Server-side recordings via Asterisk MixMonitor</span>
            </div>
            <div class="table-responsive">
                @if($recordings->count() > 0)
                <table class="table table-hover mb-0">
                    <thead>
                        <tr>
                            <th>#</th>
                            <th>Agent</th>
                            <th>Caller</th>
                            <th>Callee</th>
                            <th>Duration</th>
                            <th>Status</th>
                            <th>Recording</th>
                            <th>Date</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach($recordings as $recording)
                        <tr>
                            <td>{{ $recording->id }}</td>
                            <td>
                                <span class="fw-semibold">
                                    {{ $recording->user?->name ?? 'N/A' }}
                                </span>
                            </td>
                            <td>{{ $recording->caller }}</td>
                            <td>{{ $recording->callee }}</td>
                            <td>
                                <i class="fas fa-clock text-muted me-1"></i>
                                {{ gmdate('i:s', $recording->duration) }}
                            </td>
                            <td>
                                @php
                                    $statusColors = [
                                        'ANSWERED' => 'success',
                                        'completed' => 'success',
                                        'NO ANSWER' => 'warning',
                                        'BUSY' => 'danger',
                                        'FAILED' => 'danger',
                                    ];
                                    $color = $statusColors[$recording->status] ?? 'secondary';
                                @endphp
                                <span class="badge bg-{{ $color }} badge-status">
                                    {{ $recording->status }}
                                </span>
                            </td>
                            <td>
                                @if($recording->recording_file)
                                <audio controls preload="none">
                                    <source src="{{ route('recordings.play', $recording->id) }}" type="audio/wav">
                                    Your browser does not support audio playback.
                                </audio>
                                @else
                                <span class="text-muted">No recording</span>
                                @endif
                            </td>
                            <td>
                                <small class="text-muted">
                                    {{ $recording->created_at?->format('M d, Y H:i') ?? 'N/A' }}
                                </small>
                            </td>
                        </tr>
                        @endforeach
                    </tbody>
                </table>
                @else
                <div class="empty-state">
                    <i class="fas fa-phone-slash d-block"></i>
                    <h5>No Recordings Yet</h5>
                    <p>Call recordings will appear here after agents make calls through the system.</p>
                </div>
                @endif
            </div>
            @if($recordings->hasPages())
            <div class="card-footer bg-white border-top p-3">
                {{ $recordings->links() }}
            </div>
            @endif
        </div>
    </div>

    <!-- Footer -->
    <footer class="text-center py-4 text-muted">
        <small>Call Center System &copy; {{ date('Y') }} | Powered by Asterisk 20 + Laravel</small>
    </footer>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
