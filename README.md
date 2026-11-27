# Dhaka Metro Smart Ticket Vending Machine

**SystemVerilog RTL Project | Work in Progress**

## Project Overview

This project focuses on the RTL design of a smart metro ticket vending machine inspired by the passenger ticketing and ticket-validation workflow required for Dhaka Metro. The goal is to develop a modular digital controller that can manage the complete ticket-purchase process, including route selection, fare calculation, payment handling, ticket issuance, and ticket authentication at the entry gate.

The design is being developed in **SystemVerilog**, with particular attention to transaction integrity, cash management, and reliable ticket validation. The current repository contains the developing RTL blocks and their integration; it should be treated as a prototype rather than a production-ready or deployed metro system.

## Main Objectives

### 1. Safe Transaction Controller

The primary objective is to make each vending transaction safe and financially consistent. The controller is intended to coordinate payment acceptance, cash escrow, inventory updates, change dispensing, refunds, and card-payment recovery. A transaction should not be treated as successfully completed until its required payment and ticketing operations have reached the appropriate completion states.

Key areas include:

- Accepting supported cash denominations and rejecting notes flagged invalid by the external validator input or not included in the supported denomination set.
- Keeping inserted cash in escrow until the transaction is committed or refunded.
- Tracking the available note and coin inventory, recycler capacity, and collection-box capacity.
- Planning change and compensation using the available inventory.
- Handling cancellation, failed operations, refunds, and recovery conditions.
- Preventing conflicting cash operations, such as simultaneous change and compensation dispensing.

### 2. Ticket Authentication

The second main objective is to ensure that a ticket is authenticated before the gate is allowed to open. The current RTL includes ticket-ID generation and a ticket registry that records ticket information for later validation.

The registry checks whether a scanned ticket:

- Exists in the registered-ticket table.
- Has not already been used.
- Has not expired.
- Is being presented at its registered destination station.

A valid, unused, unexpired ticket presented at the correct station can generate a gate-open request. Invalid, expired, previously used, or wrong-station tickets are rejected.

**Security note:** The current `ticket_id_generator` creates sequential 32-bit identifiers. The registry provides functional validation and replay/expiry checks, but sequential IDs alone are not a cryptographically secure ticket credential. A real deployment would need authenticated ticket data (for example, a signed or MAC-protected QR payload), secure key management, and a clearly defined online/offline validation strategy.

## Current Development Status

We are currently working on developing and integrating a **complete metro ticket vending machine for Dhaka Metro**. The uploaded RTL is part of that ongoing work. The broader target is to bring the payment controller, cash inventory manager, smart-card functions, ticket issuing logic, ticket registry, and gate-validation logic together into one coherent vending-machine system.

The current design models peripheral interactions through digital input and output signals. The note-validity indication is supplied as an external sensor/validator input; physical counterfeit-detection circuitry is not implemented by this RTL itself. Integration with real banknote validators, cash dispensers, ticket printers, QR scanners, card readers, and physical gate hardware remains part of the wider development and verification work.

## Current RTL Features

The larger RTL design includes the following modules:

| Module | Responsibility |
|---|---|
| `smart_ticket_vending_top` | Top-level integration of the vending-machine control blocks. |
| `vending_fsm` | Controls the transaction sequence, cancellation, timeouts, recharge flow, and service-error recovery. |
| `fare_calculation` | Calculates the fare from the selected source and destination stations and flags invalid routes. |
| `payment_controller` | Tracks cash payment, validates supported note values, and determines whether the fare has been paid. |
| `cash_inventory_controller` | Manages cash escrow, note and coin inventory, recyclers, collection boxes, refunds, change, and compensation. |
| `sequential_change_planner` | Searches for an exact change or compensation combination using the available denomination inventory. |
| `rapid_card_controller` | Handles the smart-card-related operations, including card loading, payment, recharge, and refund-related control. |
| `ticket_id_generator` | Generates sequential ticket identifiers. |
| `ticket_registry` | Registers issued ticket IDs and checks ticket validity, usage status, expiry, and destination station. |
| `ticket_stock_monitor` | Monitors paper-ticket and card stock and supports the configured QR fallback mode. |
| `cash_liability_manager` | Tracks outstanding cash liabilities that may need to be settled through change or compensation. |
| `revenue_report_controller` | Maintains transaction and revenue-related accounting totals. |
| `cdc_request_capture` / `level_synchronizer` | Capture or synchronize external request signals into the system clock domain. |
| `timebase_generator` | Generates the timing tick used by time-dependent functions such as ticket expiry. |
| `display_controller` | Converts controller status and transaction information into display status signals. |

## Simplified Transaction Flow

1. A passenger selects a source station and a destination station.
2. The fare-calculation block checks the route and calculates the required fare.
3. The passenger pays using cash or the configured smart-card path.
4. The vending FSM coordinates payment verification, cash/card settlement, and ticket-slot reservation.
5. The system generates a ticket ID and requests physical or digital ticket issuance, depending on the configured mode and available stock.
6. The issued ticket is registered with its destination and issue time.
7. At the gate, the scanned ticket ID is checked against the registry. The gate-open request is generated only when the ticket passes the programmed validation checks.

## Safety and Verification Focus

Safety is a central design objective. The uploaded cash-inventory RTL contains local assertions, and a formal-oriented `smart_ticket_safety_checker` is provided under the `FORMAL` compile guard.

The system-level checker describes these intended properties:

| Property | Safety requirement |
|---|---|
| P1 — Money conservation | At transaction settlement, money received must equal the fare retained plus confirmed change, refunds, and compensation returned. |
| P2 — Payment before ticket issue | A ticket must not be issued unless payment succeeded in the same transaction. |
| P3 — Escrow recovery | An aborted transaction with non-empty escrow must reach confirmed escrow return or a service-error state. |
| P4 — Card rollback | A failed transaction after a successful card debit must complete rollback or enter a service-error state within the configured recovery bound. |
| P5 — Gate authorization | The gate must not open unless the scanned ticket is marked valid and unused; the ticket-registry logic also checks expiry and destination station. |
| P6 — Request freshness | An accepted request must belong to the current transaction epoch. |
| P7 — Counter overflow protection | Accounting counters must saturate and raise an overflow indication instead of wrapping around. |
| P8 — Bounded FSM recovery | After external inputs and pending responses stop, the FSM must reach `IDLE` or `SERVICE_ERROR` within the configured recovery bound. |
| P9 — Cash-operation exclusion | Change and compensation dispensing must not occur together; planner launches and escrow operations must obey the defined mutual-exclusion checks. |

**Verification note:** These properties describe the intended checks, not a claim that formal verification has already passed. P1–P8 require the checker to be instantiated and connected to the corresponding signals in the integrated top-level design. The comments in the checker also distinguish confirmed physical returns from internal bookkeeping pulses. The relevant formal tool setup, assumptions, and proof results should be documented as verification progresses.

## Repository Contents

The current GitHub repository view shows the cash-inventory/safety-property source file and the metro-vending RTL entry. For easier collaboration and tool recognition, the recommended layout is:

```text
.
├── README.md
├── rtl/
│   ├── metro_vending_ticket.sv  # contains smart_ticket_vending_top and supporting RTL modules
│   └── cash_inventory_controller_with_safety_properties.sv
├── tb/
│   └── (self-checking testbenches to be added)
├── constraints/
│   └── (timing constraints to be added when the target clock/interface is defined)
└── LICENSE
```

The layout above is a suggested organization; the source files can remain in their current locations until they are reorganized. The GitHub entry currently displayed as `metro_vending_ticket` has no visible `.sv` extension in the supplied screenshot. Renaming it to `metro_vending_ticket.sv` is recommended. The top-level module inside that RTL source is `smart_ticket_vending_top`.

**Integration caution:** Both uploaded source files currently define a module named `cash_inventory_controller`. Compiling both files together as-is can therefore cause a duplicate-module definition error. Keep one authoritative implementation, or replace/rename the embedded definition before adding the standalone safety-property version to the same compile list.

## Development Roadmap

- Complete and review the integration of the vending FSM, payment paths, cash inventory, ticket issuance, and ticket registry.
- Add self-checking SystemVerilog testbenches for successful purchases, invalid routes, underpayment, invalid notes, exact change, insufficient change, cancellation, refunds, card rollback, ticket expiry, replay attempts, and wrong-station scans.
- Connect the system-level safety checker to the real top-level transaction, card, ticket, gate, and accounting signals.
- Run simulation and formal checks, record the tool versions and results, and fix any issues identified.
- Define and verify the interfaces for the physical peripherals and the gate controller.
- Add architecture diagrams, timing constraints, and implementation documentation as the design matures.

## Project Scope and Disclaimer

This repository is an engineering prototype developed for learning, design, and evaluation. It is not an official Dhaka Metro Rail or Dhaka Mass Transit Company Limited (DMTCL) system, and it is not represented as being approved for deployment in a live metro environment. Real deployment would require extensive hardware integration, security review, reliability testing, and approval by the relevant authorities.

## License and Source Use

The uploaded RTL source includes an **All Rights Reserved** copyright notice and states that reuse, modification, redistribution, and commercial use require prior written permission. Please keep the repository's `LICENSE` file consistent with that notice and add it to the repository if it is not already present.
