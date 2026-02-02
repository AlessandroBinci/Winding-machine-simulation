FB_SimulazioneAzione

VAR_INPUT
    bStart : BOOL;        // Avvio
    tDurata : TIME;       // Tempo
END_VAR
VAR_OUTPUT
    bBusy : BOOL;
    bDone : BOOL;
END_VAR
VAR
    fbTimer : TON;        // Timer standard
END_VAR

---------------------------------------------------------------------------------------

// Logica Semplificata e Robusta
// Il timer conta se bStart è attivo
fbTimer(IN := bStart, PT := tDurata);

// bDone diventa TRUE solo quando il timer ha finito
bDone := fbTimer.Q;

// bBusy è TRUE se ho lo start ma non ho ancora finito
bBusy := bStart AND NOT bDone;