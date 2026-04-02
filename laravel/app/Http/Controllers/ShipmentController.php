<?php

namespace App\Http\Controllers;

use App\Models\Shipment;
use Illuminate\Http\Request;

class ShipmentController extends Controller
{
    /**
     * GET /api/shipments
     * Returns list with id, recipient_name, phone_number
     */
    public function index(Request $request)
    {
        $shipments = Shipment::select('id', 'tracking_number', 'recipient_name', 'phone_number', 'address', 'status', 'notes')
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json([
            'success'   => true,
            'shipments' => $shipments,
        ]);
    }

    /**
     * GET /api/shipments/{id}
     */
    public function show($id)
    {
        $shipment = Shipment::findOrFail($id);

        return response()->json([
            'success'  => true,
            'shipment' => $shipment,
        ]);
    }
}
