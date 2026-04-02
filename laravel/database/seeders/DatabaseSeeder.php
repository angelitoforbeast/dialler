<?php

namespace Database\Seeders;

use App\Models\User;
use App\Models\Shipment;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // Get server IP for SIP server field
        $serverIp = trim(shell_exec("hostname -I | awk '{print $1}'")) ?: 'YOUR_VPS_IP';

        // Create 25 agents
        for ($i = 1; $i <= 25; $i++) {
            User::create([
                'name'         => "Agent $i",
                'email'        => "agent{$i}@demo.com",
                'password'     => Hash::make('password123'),
                'sip_account'  => "agent{$i}",
                'sip_password' => "AgentPass{$i}2024",
                'sip_server'   => "{$serverIp}:8088",
            ]);
        }

        // Create sample shipments
        $shipments = [
            ['tracking_number' => 'SHP-2024-001', 'recipient_name' => 'Juan Dela Cruz',    'phone_number' => '09171234567', 'address' => '123 Rizal St, Manila',         'status' => 'pending'],
            ['tracking_number' => 'SHP-2024-002', 'recipient_name' => 'Maria Santos',       'phone_number' => '09181234567', 'address' => '456 Mabini Ave, Quezon City',   'status' => 'in_transit'],
            ['tracking_number' => 'SHP-2024-003', 'recipient_name' => 'Pedro Reyes',        'phone_number' => '09191234567', 'address' => '789 Bonifacio Blvd, Makati',    'status' => 'pending'],
            ['tracking_number' => 'SHP-2024-004', 'recipient_name' => 'Ana Garcia',         'phone_number' => '09201234567', 'address' => '321 Luna St, Pasig',            'status' => 'pending'],
            ['tracking_number' => 'SHP-2024-005', 'recipient_name' => 'Jose Mendoza',       'phone_number' => '09211234567', 'address' => '654 Aguinaldo Rd, Taguig',      'status' => 'in_transit'],
            ['tracking_number' => 'SHP-2024-006', 'recipient_name' => 'Rosa Villanueva',    'phone_number' => '09221234567', 'address' => '987 Del Pilar St, Mandaluyong', 'status' => 'pending'],
            ['tracking_number' => 'SHP-2024-007', 'recipient_name' => 'Carlos Ramos',       'phone_number' => '09231234567', 'address' => '147 Quezon Ave, Caloocan',      'status' => 'pending'],
            ['tracking_number' => 'SHP-2024-008', 'recipient_name' => 'Elena Torres',       'phone_number' => '09241234567', 'address' => '258 Roxas Blvd, Paranaque',     'status' => 'delivered'],
            ['tracking_number' => 'SHP-2024-009', 'recipient_name' => 'Roberto Cruz',       'phone_number' => '09251234567', 'address' => '369 Osmena St, Las Pinas',      'status' => 'pending'],
            ['tracking_number' => 'SHP-2024-010', 'recipient_name' => 'Lorna Bautista',     'phone_number' => '09261234567', 'address' => '741 Magsaysay Ave, Muntinlupa', 'status' => 'pending'],
            ['tracking_number' => 'SHP-2024-011', 'recipient_name' => 'Ricardo Fernandez',  'phone_number' => '09271234567', 'address' => '852 Laurel St, Valenzuela',     'status' => 'in_transit'],
            ['tracking_number' => 'SHP-2024-012', 'recipient_name' => 'Teresa Aquino',      'phone_number' => '09281234567', 'address' => '963 Marcos Ave, Marikina',      'status' => 'pending'],
            ['tracking_number' => 'SHP-2024-013', 'recipient_name' => 'Antonio Gonzales',   'phone_number' => '09291234567', 'address' => '159 Recto St, San Juan',        'status' => 'pending'],
            ['tracking_number' => 'SHP-2024-014', 'recipient_name' => 'Carmen Pascual',     'phone_number' => '09301234567', 'address' => '267 Taft Ave, Pasay',           'status' => 'failed'],
            ['tracking_number' => 'SHP-2024-015', 'recipient_name' => 'Miguel Soriano',     'phone_number' => '09311234567', 'address' => '378 España Blvd, Sampaloc',     'status' => 'pending'],
        ];

        foreach ($shipments as $shipment) {
            Shipment::create($shipment);
        }
    }
}
