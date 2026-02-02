FB_MacchinaLancio

VAR_INPUT
    bStartLavoro : BOOL;      // Comando dal Main: "Inizia ciclo lancio"
    bMoverPronto : BOOL;      // Consenso: "Il mover è davanti a me"
END_VAR

VAR_OUTPUT
    bBusy : BOOL;             // Sto lavorando
    bDone : BOOL;             // Ciclo finito (filo tagliato)
    
    // Segnali verso il Mover/Motore
    bRichiestaChiusuraPinza : BOOL; // Dico al Mover: "Chiudi ora!"
    bFiloInTensione : BOOL;         // Dico al Motore: "Puoi avvolgere"
END_VAR

VAR
    iStep : INT := 0;
    fbTimer1 : TON; // Timer per avvicinamento
    fbTimer2 : TON; // Timer per pinzatura
END_VAR

--------------------------------------------------------------------------------------------

CASE iStep OF
    0: // IDLE
        bBusy := FALSE;
        bDone := FALSE;
        bRichiestaChiusuraPinza := FALSE;
        bFiloInTensione := FALSE;
		// Reset dei timer
        fbTimer1(IN := FALSE);
        fbTimer2(IN := FALSE);
        
        IF bStartLavoro AND bMoverPronto THEN
            bBusy := TRUE;
            iStep := 10;
        END_IF
        
    10: // AVVICINAMENTO FILO (Simulazione tempo meccanico)
        fbTimer1(IN := TRUE, PT := T#1S);
        IF fbTimer1.Q THEN
            iStep := 20;
        END_IF
        
    20: // PINZATURA (Dico al mover di chiudere)
        bRichiestaChiusuraPinza := TRUE; 
        // Aspetto che la pinza sia chiusa (simuliamo un tempo di feedback)
        fbTimer2(IN := TRUE, PT := T#0.5S);
        IF fbTimer2.Q THEN
            bFiloInTensione := TRUE; // Do il consenso all'avvolgitore
            iStep := 30; // Ora aspetto che l'esterno (Main) mi dica che ha finito di avvolgere
        END_IF
        
    30: // ATTESA AVVOLGIMENTO
        // Nota: Resto qui finché bStartLavoro è TRUE. 
        // Quando l'avvolgimento finisce, il Main toglierà bStartLavoro, 
        // ma noi dobbiamo gestire il taglio prima di finire.
        // PER ORA: Simuliamo che gestiamo noi il taglio dopo un tempo, 
        // oppure (meglio) restiamo in attesa passiva e il Main ci resetta.
        
        // In questa logica semplificata, consideriamo il taglio fatto alla fine
        // quando il motore ha finito.
        ; 
        
END_CASE

// Logica di uscita/reset forzato se cade lo start
IF NOT bStartLavoro AND iStep > 0 THEN
    // Fase di taglio simulata al rilascio
    bFiloInTensione := FALSE;
    bRichiestaChiusuraPinza := TRUE; // Tengo il filo finché non riparte il mover
    bDone := TRUE;
    iStep := 0;
END_IF