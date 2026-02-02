# Winding-machine-simulation
Simulazione PLC (CODESYS/ST) di una macchina avvolgitrice a 4 mover. Include gestione cambio formato dinamico, logica di emergenza con ripresa in fase e gestione scarti.
(**ENGLISH VERSION:** PLC Simulation (CODESYS/ST) of a 4-mover cable winding machine. Features dynamic format change, emergency handling with phase resume, and reject management. 
 *For English version explanation see below.*)

# Simulazione Macchina Avvolgitrice Cavi (PLC / CODESYS)

Questo repository contiene il progetto completo di una simulazione per una macchina avvolgitrice automatica, sviluppato in **CODESYS** utilizzando il linguaggio **Structured Text (IEC 61131-3)**.

Il progetto simula un sistema a **multitransport (XTS/Mover)** con 4 carrelli indipendenti che processano cavi elettrici attraverso diverse stazioni di lavorazione.

## Funzionalità Principali

* **Logica a 4 Mover Indipendenti:** Gestione asincrona di 4 unità (Gruppi) che si muovono tra le stazioni.
* **Gestione Cambio Formato Dinamico:**
    * Il sistema gestisce lotti di produzione diversi (es. lunghezze cavo 3000mm, 9000mm, 15000mm).
    * Calcolo automatico dei parametri fisici: la rotazione di correzione (in gradi) viene calcolata matematicamente in base al diametro del mandrino e alla lunghezza del lembo di cavo.
* **Gestione Emergenza Avanzata:**
    * **Stop in Fase (Freeze):** Arresto immediato di tutti gli assi e timer in caso di emergenza.
    * **Ripresa in Fase (Phase Resume):** Al ripristino, la macchina riparte esattamente dal punto e dalla velocità in cui si era interrotta, senza perdere la logica sequenziale.
* **Gestione Scarti (Reject Logic):** Se l'emergenza avviene durante una fase critica (es. avvolgimento), il pezzo viene marcato come "difettoso" e conteggiato separatamente dagli scarti a fine linea.
* **Simulazione Fisica:** Logica di accelerazione/decelerazione del mandrino e calcolo dei tempi di processo realistici.

## Screenshots
![Panoramica Impianto](screenshots/overview.png)

## Struttura dell'Impianto

La simulazione gestisce il ciclo di vita del prodotto attraverso 3 stazioni principali:

1.  **Stazione 1 (Avvolgimento):**
    * Carico del filo tramite braccio meccanico.
    * Avvolgimento veloce (simulazione RPM reali).
    * Taglio del cavo.
2.  **Stazione 2 (Correzione/Piegatura):**
    * Il mover ruota il mandrino di un angolo specifico.
    * L'angolo è variabile e calcolato in base al formato corrente (gestione della "memoria" del formato per ogni singolo mover).
3.  **Stazione 3 (Scarico):**
    * Rilascio del prodotto finito.
    * Conteggio pezzi (Buoni vs Scartati).
    * Ritorno del mover al punto di partenza.

## Dettagli Tecnici

* **Ambiente di Sviluppo:** CODESYS V3.5 (o superiore).
* **Linguaggio:** Structured Text (ST).
* **Architettura:**
    * `PLC_PRG`: Programma principale che gestisce la macchina a stati, le chiamate ai blocchi e la sicurezza.
    * `FB_Mover`: Function Block istanziato 4 volte per gestire la logica del singolo carrello.
    * `FB_StazioneAvvolgimento` & `FB_SimulazioneAzione`: Blocchi per la simulazione dei sottosistemi.

## Come utilizzare il progetto

1.  Clona il repository o scarica lo zip.
2.  Apri il file `.project` con CODESYS.
3.  Esegui la compilazione e avvia la simulazione (Login -> Run).
4.  Apri la pagina di **Visualizzazione** integrata per interagire con il pannello comandi (Start, Fungo Emergenza, Reset, Monitoraggio Ordini).

## Note sulla Sicurezza (Simulata)

La logica del pulsante di emergenza segue lo standard industriale:
1.  Pressione Fungo -> **Stop Immediato**.
2.  Rilascio Fungo -> **Stato di Attesa**.
3.  Pressione Reset -> **Riavvio in Fase**.

---
*Progetto sviluppato a scopo didattico e di simulazione automazione industriale.*

------------------------------------------------------------------------------------------------------------------------------------------------------
# ENGLISH VERSION
# Cable Winding Machine Simulation (PLC / CODESYS)

This repository contains a complete simulation project for an automatic cable winding machine, developed in **CODESYS** using **Structured Text (IEC 61131-3)** language.

The project simulates a **multi-carrier system (XTS/Mover)** with 4 independent movers processing electrical cables through various workstations.

## Key Features

* **4 Independent Movers Logic:** Asynchronous management of 4 units (Groups) moving between stations.
* **Dynamic Format Changeover:**
    * The system handles different production batches (e.g., cable lengths of 3000mm, 9000mm, 15000mm).
    * **Automatic calculation of physical parameters:** The correction rotation angle is mathematically calculated based on the mandrel diameter and the length of the cable tail.
* **Advanced Emergency Handling:**
    * **Freeze/Stop in Phase:** Immediate halt of all axes and timers when the Emergency Stop is pressed.
    * **Phase Resume:** Upon reset, the machine resumes exactly from the point and speed where it stopped, preserving the sequential logic state.
* **Reject Management (Quality Control):** If an emergency stop occurs during a critical phase (e.g., winding), the specific piece is marked as "defective" and counted separately as scrap at the end of the line.
* **Physical Simulation:** Logic for mandrel acceleration/deceleration and calculation of realistic process times.

## Plant Structure

The simulation manages the product lifecycle through 3 main stations:

1.  **Station 1 (Winding):**
    * Wire loading via mechanical arm simulation.
    * High-speed winding (Real RPM simulation).
    * Cable cutting.
2.  **Station 2 (Correction/Bending):**
    * The mover rotates the mandrel by a specific angle.
    * The angle is variable and calculated based on the *current* format (each mover retains "memory" of which format it is carrying).
3.  **Station 3 (Unloading):**
    * Finished product release.
    * Piece counting (Good vs. Scrap).
    * Mover return to the start position.

## Technical Details

* **Development Environment:** CODESYS V3.5 (or higher).
* **Language:** Structured Text (ST).
* **Architecture:**
    * `PLC_PRG`: Main program managing the state machine, function block calls, and safety logic.
    * `FB_Mover`: Function Block instantiated 4 times to handle the logic of each single carrier.
    * `FB_StazioneAvvolgimento` & `FB_SimulazioneAzione`: Blocks for subsystem simulation.

## How to use

1.  Clone the repository or download the ZIP.
2.  Open the `.project` file with CODESYS.
3.  Compile and start the simulation (Login -> Run).
4.  Open the integrated **Visualization** page to interact with the control panel (Start, Emergency Stop, Reset, Order Monitoring).

## Safety Logic Notes

The emergency button logic follows industrial standards:
1.  Button Pressed -> **Immediate Stop (Freeze)**.
2.  Button Released -> **Wait State**.
3.  Reset Pressed -> **Resume in Phase**.

---
*Project developed for educational purposes and industrial automation simulation.*
