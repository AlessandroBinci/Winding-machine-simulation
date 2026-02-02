FB_Mover


VAR_INPUT
    // --- MOVIMENTO ---
    fTargetX : REAL;      
    fTargetY : REAL;      
    fVelocita : REAL := 10.0; 
    bAbilitaMovimento : BOOL; 
    
    // Init
    bInizializza : BOOL; 
    fInitX : REAL;        
    fInitY : REAL;        

    // --- COMANDI MECCANICI ---
    bChiudiPinza   : BOOL; 
    bCaricaBobina  : BOOL; 
    bScaricaBobina : BOOL; 
    
    iRotazioneVisiva : INT; 
    
    // --- NUOVA VARIABILE (SPOSTATA QUI) ---
    fRotazioneGruppo : INT := 0; // Angolo rotazione intero gruppo (0-360)
	
	bPezzoScartato : BOOL := FALSE; // Memoria: questo pezzo è difettoso?
	
	bPezzoPresente : BOOL := FALSE; // TRUE = Ho caricato il filo, FALSE = Sono vuoto
END_VAR

VAR_OUTPUT
    bInPosizione : BOOL;  
    
    // --- STATI ---
    bPinzaChiusa_Out : BOOL; 
    bMandrinoPieno   : BOOL; 
    bFiloRossoVisibile : BOOL;
END_VAR

VAR
    fAttualeX : REAL;      
    fAttualeY : REAL;      
    iDatiCavo : ST_DatiProdotto; 
END_VAR

---------------------------------------------------------------------------------------------------------------------

// 1. GESTIONE INIZIALIZZAZIONE
IF bInizializza THEN
    fAttualeX := fInitX;
    fAttualeY := fInitY;
    bInPosizione := TRUE;
    // Reset stati meccanici all'avvio
    bPinzaChiusa_Out := FALSE;
    bMandrinoPieno := FALSE;
    RETURN; 
END_IF

// 2. LOGICA MOVIMENTO (X e Y)
IF bAbilitaMovimento THEN
    // X
    IF ABS(fAttualeX - fTargetX) > fVelocita THEN
        IF fAttualeX < fTargetX THEN fAttualeX := fAttualeX + fVelocita;
        ELSE fAttualeX := fAttualeX - fVelocita; END_IF
    ELSE fAttualeX := fTargetX; END_IF
    
    // Y
    IF ABS(fAttualeY - fTargetY) > fVelocita THEN
        IF fAttualeY < fTargetY THEN fAttualeY := fAttualeY + fVelocita;
        ELSE fAttualeY := fAttualeY - fVelocita; END_IF
    ELSE fAttualeY := fTargetY; END_IF
END_IF

// Controllo posizione
IF ABS(fAttualeX - fTargetX) < 1.0 AND ABS(fAttualeY - fTargetY) < 1.0 THEN
    bInPosizione := TRUE;
ELSE
    bInPosizione := FALSE;
END_IF

// 3. LOGICA MECCANICA (Nuova)
// La pinza segue direttamente il comando (es. elettrovalvola monostabile)
bPinzaChiusa_Out := bChiudiPinza;

// Gestione presenza bobina (Set/Reset)
IF bCaricaBobina THEN
    bMandrinoPieno := TRUE;
ELSIF bScaricaBobina THEN
    bMandrinoPieno := FALSE;
END_IF