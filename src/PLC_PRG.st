PROGRAM PLC_PRG
VAR
    bReset : BOOL := FALSE; 
    bM2_AbilitaRotazione : BOOL := FALSE;
	
    // --- GESTIONE EMERGENZA ---
    bFungoEmergenza      : BOOL := FALSE; // HMI: Toggle
    bPulsanteResetEmerg  : BOOL := FALSE; // HMI: Tap
    bEmergenzaAttiva     : BOOL := FALSE; 
    
    // Trigger per scarti
    R_TRIG_Emergenza : R_TRIG;
    
	// Variabili per non ripetere il cambio formato
	bSetupFatto_M1 : BOOL := FALSE;
    bSetupFatto_M2 : BOOL := FALSE;
    bSetupFatto_M3 : BOOL := FALSE;
    bSetupFatto_M4 : BOOL := FALSE;
	iTargetFuturo : INT;
	iIndiceLottoFuturo : INT := 0;
	
    // --- OGGETTI ---
    Mover1, Mover2, Mover3, Mover4 : FB_Mover;
    LancioCavo        : FB_MacchinaLancio;
    MotoreAvvolgimento: FB_StazioneAvvolgimento;
    
    // Black Boxes
    RobotTransfer     : FB_SimulazioneAzione; 
    ScaricoLegatura   : FB_SimulazioneAzione; 
    Setup_M1, Setup_M2, Setup_M3, Setup_M4 : FB_SimulazioneAzione; 
    SimulazioneCorrezione : FB_SimulazioneAzione; 
    SimulazioneTaglio     : FB_SimulazioneAzione; 

    // --- GESTIONE PRODUZIONE & DATI REALI ---
    ListaOrdini : ARRAY[1..3] OF ST_Ordine := [
        (sNomeOrdine:='Ordine 3000mm (90deg)', iQuantitaTarget:=10, fLunghezzaCavo:=3000, fDiametro:=230.6, fCorrezione:=90.5),
        (sNomeOrdine:='Ordine 9000mm (45deg)', iQuantitaTarget:=10, fLunghezzaCavo:=9000, fDiametro:=200.0, fCorrezione:=157.0),
        (sNomeOrdine:='Ordine 15000mm (20deg)', iQuantitaTarget:=10, fLunghezzaCavo:=15000, fDiametro:=180.0, fCorrezione:=30.0)
    ];
    
    iIndiceOrdineCorrente : INT := 1;
    iPezziProdotti        : INT := 0;
    iPezziScartati        : INT := 0; 
    iPezziMancanti        : INT;
    
    // CALCOLO PARAMETRI FISICI
    fCirconferenzaCorrente     : REAL;
    iTargetRotazioneCorrezione : INT;
    
    // GESTIONE CAMBIO FORMATO
    iContatoreSetup : INT := 0;       
    bTriggerLanciato : BOOL := FALSE; 
    
    // --- VARIABILI GRAFICHE E SPIE ---
    fLunghezzaMetri : REAL;
    bSpiaSetup, bSpiaAvvolgimento, bSpiaLancio, bSpiaCorrezione, bSpiaTaglio, bSpiaAttuatore : BOOL;
    
    // Animazione Tubo/Filo Stazione 1
    fAnim_PosizioneTubo : REAL := 0;
    fAnim_LunghezzaFilo : REAL := 0;
    dwAnim_ColoreFilo   : DWORD := 16#FF000000;
    COLORE_NERO : DWORD := 16#FF000000;
    COLORE_ROSSO: DWORD := 16#FFFF0000;
    
    // --- GESTIONE MOVIMENTI ---
    bStartCiclo : BOOL := FALSE; 
    bM1_Pronto, bM2_Pronto, bM3_Pronto, bM4_Pronto : BOOL;
    bMuoviTutti : BOOL;
    
    TargetX_M1, TargetY_M1, Vel_M1 : REAL;
    TargetX_M2, TargetY_M2, Vel_M2 : REAL;
    TargetX_M3, TargetY_M3, Vel_M3 : REAL;
    TargetX_M4, TargetY_M4, Vel_M4 : REAL;
    
    iPassoMover1, iPassoMover2, iPassoMover3, iPassoMover4 : INT := 0;

    fVelocitaLavoro  : REAL := 9.0;   
    fVelocitaRitorno : REAL := 15.0;  
    
    DatiProdottoCorrente : ST_DatiProdotto;
    tTempoST2 : TIME := T#1.5S; 
    tTempoST3 : TIME := T#2S;
	
	//variabili di memoria angolo
	iMemoriaGradi_M1 : INT := 0;
    iMemoriaGradi_M2 : INT := 0;
    iMemoriaGradi_M3 : INT := 0;
    iMemoriaGradi_M4 : INT := 0;
END_VAR

----------------------------------------------------------------------------------------------------------------------------------------------

// =============================================================
// CODICE PRINCIPALE
// =============================================================

// 1. LOGICA EMERGENZA
IF bFungoEmergenza THEN
    bEmergenzaAttiva := TRUE;

ELSIF (NOT bFungoEmergenza) AND bPulsanteResetEmerg THEN
    bEmergenzaAttiva := FALSE;
END_IF

// 2. CONTEGGIO SCARTI (Trigger su fronte salita emergenza)
R_TRIG_Emergenza(CLK := bEmergenzaAttiva);

IF R_TRIG_Emergenza.Q THEN
    IF iPassoMover1 = 20 THEN
        Mover1.bPezzoScartato := TRUE;
    END_IF

    IF iPassoMover2 = 20 THEN
        Mover2.bPezzoScartato := TRUE;
    END_IF

    IF iPassoMover3 = 20 THEN
        Mover3.bPezzoScartato := TRUE;
    END_IF

    IF iPassoMover4 = 20 THEN
        Mover4.bPezzoScartato := TRUE;
    END_IF
END_IF

// =============================================================
// LOGICA MACCHINA (Eseguita se NO Emergenza)
// =============================================================
IF NOT bEmergenzaAttiva THEN

    // --- RIPRISTINO VELOCITÀ "BLINDATO" ---
    // (Ripristina la velocità se usciamo da un'emergenza)

    // MOVER 1
    IF Vel_M1 = 0 THEN
        IF iPassoMover1 <= 65 THEN
            Vel_M1 := fVelocitaLavoro;
        ELSE
            Vel_M1 := fVelocitaRitorno;
        END_IF
    END_IF

    // MOVER 2
    IF Vel_M2 = 0 THEN
        IF iPassoMover2 <= 65 THEN
            Vel_M2 := fVelocitaLavoro;
        ELSE
            Vel_M2 := fVelocitaRitorno;
        END_IF
    END_IF

    // MOVER 3
    IF Vel_M3 = 0 THEN
        IF iPassoMover3 <= 65 THEN
            Vel_M3 := fVelocitaLavoro;
        ELSE
            Vel_M3 := fVelocitaRitorno;
        END_IF
    END_IF

    // MOVER 4
    IF Vel_M4 = 0 THEN
        IF iPassoMover4 <= 65 THEN
            Vel_M4 := fVelocitaLavoro;
        ELSE
            Vel_M4 := fVelocitaRitorno;
        END_IF
    END_IF

    // --- RESET / STARTUP ---
    IF bReset OR (iPassoMover1 = 0) THEN
        Mover1.fInitX := 1500;
        Mover1.fInitY := 0;
        TargetX_M1   := 1500;
        TargetY_M1   := 0;

        Mover2.fInitX := 900;
        Mover2.fInitY := 0;
        TargetX_M2   := 900;
        TargetY_M2   := 0;

        Mover3.fInitX := 0;
        Mover3.fInitY := 0;
        TargetX_M3   := 0;
        TargetY_M3   := 0;

        Mover4.fInitX := 1500;
        Mover4.fInitY := 1100;
        TargetX_M4   := 1500;
        TargetY_M4   := 1100;

        iPassoMover1 := 10;
        iPassoMover2 := 30;
        iPassoMover3 := 60;
        iPassoMover4 := 90;

        Setup_M1(bStart := FALSE);
        Setup_M2(bStart := FALSE);
        Setup_M3(bStart := FALSE);
        Setup_M4(bStart := FALSE);

        RobotTransfer(bStart := FALSE);
        ScaricoLegatura(bStart := FALSE);
        MotoreAvvolgimento(bStart := FALSE);
        LancioCavo(bStartLavoro := FALSE);

        SimulazioneCorrezione(bStart := FALSE);
        SimulazioneTaglio(bStart := FALSE);

        bSpiaLancio     := FALSE;
        bSpiaCorrezione := FALSE;
        bSpiaTaglio     := FALSE;
        bSpiaAttuatore  := FALSE;

        Mover1.bInizializza     := TRUE;
        Mover1.bChiudiPinza     := FALSE;
        Mover1.bCaricaBobina    := FALSE;
        Mover1.fRotazioneGruppo := 0;
		Mover2.iRotazioneVisiva := 0;
        Mover1.bPezzoScartato   := FALSE;
		Mover1.bPezzoPresente := FALSE;

        Mover2.bInizializza     := TRUE;
		bM2_AbilitaRotazione 	:= FALSE;
        Mover2.bChiudiPinza     := FALSE;
        Mover2.bCaricaBobina    := FALSE;
        Mover2.fRotazioneGruppo := 0;
        Mover2.bPezzoScartato   := FALSE;
		Mover2.bPezzoPresente := FALSE;

        Mover3.bInizializza     := TRUE;
        Mover3.bChiudiPinza     := FALSE;
        Mover3.bCaricaBobina    := FALSE;
        Mover3.fRotazioneGruppo := 0;
		Mover3.iRotazioneVisiva := 0;
        Mover3.bPezzoScartato   := FALSE;
		Mover3.bPezzoPresente := FALSE;

        Mover4.bInizializza     := TRUE;
        Mover4.bChiudiPinza     := FALSE;
        Mover4.bCaricaBobina    := FALSE;
        Mover4.fRotazioneGruppo := 0;
		Mover4.iRotazioneVisiva := 0;
        Mover4.bPezzoScartato   := FALSE;
		Mover4.bPezzoPresente := FALSE;

        bReset := FALSE;

    ELSE
        Mover1.bInizializza := FALSE;
        Mover2.bInizializza := FALSE;
        Mover3.bInizializza := FALSE;
        Mover4.bInizializza := FALSE;

        // Sicurezza anti-rotazione iniziale
        IF iPassoMover1 < 40 THEN
			IF bSetupFatto_M1 THEN
            Mover1.fRotazioneGruppo := 45;
        	ELSE
            Mover1.fRotazioneGruppo := 0;
        	END_IF
            Mover1.fRotazioneGruppo := 0;
        END_IF

        IF iPassoMover2 < 40 THEN
            Mover2.fRotazioneGruppo := 0;
        END_IF

        IF iPassoMover3 < 40 THEN
            Mover3.fRotazioneGruppo := 0;
        END_IF

        IF iPassoMover4 < 40 THEN
            Mover4.fRotazioneGruppo := 0;
        END_IF
    END_IF

    // CALCOLI DI PRODUZIONE E FISICA
    iPezziMancanti := ListaOrdini[iIndiceOrdineCorrente].iQuantitaTarget - iPezziProdotti;

    DatiProdottoCorrente.fLunghezzaCavoTotale := ListaOrdini[iIndiceOrdineCorrente].fLunghezzaCavo;
    DatiProdottoCorrente.fDiametroMandrino    := ListaOrdini[iIndiceOrdineCorrente].fDiametro;
    DatiProdottoCorrente.fCorrezioneLemb      := ListaOrdini[iIndiceOrdineCorrente].fCorrezione;

    // Calcolo Angolo Correzione
    fCirconferenzaCorrente := DatiProdottoCorrente.fDiametroMandrino * 3.14159;

    IF fCirconferenzaCorrente > 0 THEN
        iTargetRotazioneCorrezione := REAL_TO_INT(
            (DatiProdottoCorrente.fCorrezioneLemb / fCirconferenzaCorrente) * 360.0
        );
    ELSE
        iTargetRotazioneCorrezione := 0;
    END_IF
	
    fLunghezzaMetri := DatiProdottoCorrente.fLunghezzaCavoTotale / 1000.0;

    // --- AGGIUNGI QUESTO BLOCCO NUOVO ---
    // Pre-calcolo per i mover che hanno GIÀ fatto il cambio formato
    IF iIndiceOrdineCorrente < 3 THEN
        // Guardo l'ordine successivo (+1)
        fCirconferenzaCorrente := ListaOrdini[iIndiceOrdineCorrente + 1].fDiametro * 3.14159;
        IF fCirconferenzaCorrente > 0 THEN
            iTargetFuturo := REAL_TO_INT((ListaOrdini[iIndiceOrdineCorrente + 1].fCorrezione / fCirconferenzaCorrente) * 360.0);
        ELSE
            iTargetFuturo := 0;
        END_IF
    ELSE
        iTargetFuturo := iTargetRotazioneCorrezione; // Finiti gli ordini
    END_IF

    // Gestione Ordini
    IF (iPezziMancanti <= 3) AND (NOT bTriggerLanciato) THEN
        iContatoreSetup  := 4;
        bTriggerLanciato := TRUE;
		iIndiceLottoFuturo := iIndiceOrdineCorrente + 1;
		// Resetta la memoria: nessuno ha ancora fatto il setup per questo nuovo ordine
        bSetupFatto_M1 := FALSE;
        bSetupFatto_M2 := FALSE;
        bSetupFatto_M3 := FALSE;
        bSetupFatto_M4 := FALSE;
    END_IF

    IF iPezziProdotti >= ListaOrdini[iIndiceOrdineCorrente].iQuantitaTarget THEN
        IF iIndiceOrdineCorrente < 3 THEN
            iIndiceOrdineCorrente := iIndiceOrdineCorrente + 1;
            iPezziProdotti        := 0;
            iPezziScartati        := 0;
            bTriggerLanciato      := FALSE;
        ELSE
            bStartCiclo := FALSE;
        END_IF
    END_IF

    // SPIE
    bSpiaSetup :=
        (iContatoreSetup > 0) AND ((iPassoMover1 = 90) OR (iPassoMover2 = 90) OR(iPassoMover3 = 90) OR (iPassoMover4 = 90));

    bSpiaAvvolgimento := (MotoreAvvolgimento.fVelocitaAttuale > 0);
    bSpiaAttuatore    := RobotTransfer.bBusy;

    IF bM1_Pronto AND bM2_Pronto AND bM3_Pronto AND bM4_Pronto AND bStartCiclo THEN
        bMuoviTutti := TRUE;
    ELSE
        bMuoviTutti := FALSE;
    END_IF

    // ANIMAZIONI
    IF (MotoreAvvolgimento.bDone = FALSE) AND (MotoreAvvolgimento.fVelocitaAttuale > 0) THEN
        IF fAnim_PosizioneTubo < 100 THEN
            fAnim_PosizioneTubo := fAnim_PosizioneTubo + 5.0;
        END_IF
    ELSE
        IF fAnim_PosizioneTubo > 0 THEN
            fAnim_PosizioneTubo := fAnim_PosizioneTubo - 5.0;
        END_IF
    END_IF

    IF LancioCavo.bBusy OR LancioCavo.bFiloInTensione THEN
        IF fAnim_LunghezzaFilo < 300 THEN
            fAnim_LunghezzaFilo := fAnim_LunghezzaFilo + 10.0;
        END_IF
    ELSE
        fAnim_LunghezzaFilo := 0;
    END_IF

    IF MotoreAvvolgimento.fVelocitaAttuale > 10.0 THEN
        dwAnim_ColoreFilo := COLORE_ROSSO;
    ELSE
        dwAnim_ColoreFilo := COLORE_NERO;
    END_IF


    // =============================================================
    // LOGICA MOVER 1
    // =============================================================
    CASE iPassoMover1 OF

        10:
            Vel_M1 := fVelocitaLavoro;
            bM1_Pronto := FALSE;
            Mover1.iRotazioneVisiva := 0;

            IF Mover1.bInPosizione AND bStartCiclo THEN
                iPassoMover1 := 20;
            END_IF

        20:
            bSpiaLancio := TRUE;

            LancioCavo(bStartLavoro := TRUE, bMoverPronto := TRUE);
            Mover1.bChiudiPinza := LancioCavo.bRichiestaChiusuraPinza;

            IF LancioCavo.bFiloInTensione THEN
                MotoreAvvolgimento(
                    bStart          := TRUE,
                    fLunghezzaTarget:= DatiProdottoCorrente.fLunghezzaCavoTotale,
                    fVelocitaMax    := 100.0
                );
                Mover1.iRotazioneVisiva := MotoreAvvolgimento.fAngoloRotazione;
            END_IF

            IF MotoreAvvolgimento.bDone THEN
                MotoreAvvolgimento(bStart := FALSE);
                LancioCavo(bStartLavoro := FALSE);

                Mover1.iRotazioneVisiva := 0;
                bSpiaLancio := FALSE;
                iPassoMover1 := 21;
            END_IF

        21:
            bSpiaCorrezione := TRUE;

            SimulazioneCorrezione(bStart := TRUE, tDurata := T#1S);

            IF SimulazioneCorrezione.bDone THEN
                SimulazioneCorrezione(bStart := FALSE);
                bSpiaCorrezione := FALSE;
                iPassoMover1 := 22;
            END_IF

        22:
            bSpiaTaglio := TRUE;

            SimulazioneTaglio(bStart := TRUE, tDurata := T#0.5S);

            IF SimulazioneTaglio.bDone THEN
                SimulazioneTaglio(bStart := FALSE);
                bSpiaTaglio := FALSE;

                Mover1.bCaricaBobina := TRUE;
				Mover1.bPezzoPresente := TRUE;
                iPassoMover1 := 11;
            END_IF

        11:
            Mover1.bCaricaBobina := FALSE;
            bM1_Pronto := TRUE;

            IF bMuoviTutti THEN
                bM1_Pronto := FALSE;
                TargetX_M1 := 900;
                TargetY_M1 := 0;
                iPassoMover1 := 30;
            END_IF

        30:
            IF Mover1.bInPosizione THEN
                iPassoMover1 := 40;
            END_IF

        40:
            Vel_M1 := fVelocitaLavoro;
            bM1_Pronto := FALSE;
            Mover1.bChiudiPinza := FALSE;

            RobotTransfer(bStart := TRUE, tDurata := tTempoST2);

            IF RobotTransfer.bBusy THEN
                
                // SE HO FATTO IL SETUP -> Uso la mia memoria (i 45 gradi)
                IF bSetupFatto_M1 THEN
                    IF Mover1.fRotazioneGruppo < iMemoriaGradi_M1 THEN  // <--- GUARDA QUI
                        Mover1.fRotazioneGruppo := Mover1.fRotazioneGruppo + 1;
                    END_IF
                
                // SE NON HO FATTO IL SETUP -> Uso i gradi vecchi normali
                ELSE
                    IF Mover1.fRotazioneGruppo < iTargetRotazioneCorrezione THEN
                        Mover1.fRotazioneGruppo := Mover1.fRotazioneGruppo + 1;
                    END_IF
                END_IF

            END_IF

            IF RobotTransfer.bDone THEN
                RobotTransfer(bStart := FALSE);
                iPassoMover1 := 41;
            END_IF

        41:
            bM1_Pronto := TRUE;

            IF bMuoviTutti THEN
                bM1_Pronto := FALSE;
                TargetX_M1 := 0;
                TargetY_M1 := 0;
                iPassoMover1 := 50;
            END_IF

        50:
            IF Mover1.bInPosizione THEN
                iPassoMover1 := 60;
            END_IF

        60:
            Vel_M1 := fVelocitaLavoro;
            bM1_Pronto := FALSE;

            ScaricoLegatura(bStart := TRUE, tDurata := tTempoST3);

            IF ScaricoLegatura.bDone THEN
                ScaricoLegatura(bStart := FALSE);
                Mover1.bScaricaBobina := TRUE;
                iPassoMover1 := 65;
            END_IF

        65:
            IF Mover1.fRotazioneGruppo > 0 THEN
                Mover1.fRotazioneGruppo := Mover1.fRotazioneGruppo - 1;
            ELSE
				IF Mover1.bPezzoPresente THEN
					IF Mover1.bPezzoScartato THEN
						iPezziScartati := iPezziScartati + 1;
						Mover1.bPezzoScartato := FALSE;
					ELSE
						iPezziProdotti := iPezziProdotti + 1;
					END_IF
					Mover1.bPezzoPresente := FALSE;
				END_IF
				iPassoMover1 := 61;
            END_IF

        61:
            Mover1.bScaricaBobina := FALSE;
            bM1_Pronto := TRUE;

            IF bMuoviTutti THEN
                bM1_Pronto := FALSE;

                TargetX_M1 := 0;
                TargetY_M1 := 1100;
                Vel_M1 := fVelocitaRitorno;

                iPassoMover1 := 70;
            END_IF

        70:
            IF Mover1.bInPosizione THEN
                TargetX_M1 := 1500;
                TargetY_M1 := 1100;
                iPassoMover1 := 80;
            END_IF

        80:
            IF Mover1.bInPosizione THEN
                Setup_M1(bStart := FALSE);
                iPassoMover1 := 90;
            END_IF

        90:
            Vel_M1 := fVelocitaRitorno;
			
            IF (iContatoreSetup > 0) AND ( NOT bSetupFatto_M1) THEN
                
                IF Setup_M1.bStart = FALSE THEN
                     iContatoreSetup := iContatoreSetup - 1;
                END_IF

                Setup_M1(bStart := TRUE, tDurata := T#4.5S);

                IF Setup_M1.bDone THEN
                    Setup_M1(bStart := FALSE);
                    bSetupFatto_M1 := TRUE; 
					fCirconferenzaCorrente := ListaOrdini[iIndiceLottoFuturo].fDiametro * 3.14159;
					IF fCirconferenzaCorrente > 0 THEN
                    iMemoriaGradi_M1 := REAL_TO_INT((ListaOrdini[iIndiceLottoFuturo].fCorrezione / fCirconferenzaCorrente) * 360.0);
                ELSE
                    iMemoriaGradi_M1 := 0;
                END_IF
                    iPassoMover1 := 91;
                END_IF

            ELSE
                // Se il contatore è 0 (o l'ho già fatto), passo veloce
                Setup_M1(bStart := TRUE, tDurata := T#0.5S);

                IF Setup_M1.bDone THEN
                    Setup_M1(bStart := FALSE);
                    iPassoMover1 := 91;
                END_IF
            END_IF

        91:
            bM1_Pronto := TRUE;

            IF bMuoviTutti THEN
                bM1_Pronto := FALSE;

                TargetX_M1 := 1500;
                TargetY_M1 := 0;
                Vel_M1 := fVelocitaRitorno;

                iPassoMover1 := 100;
            END_IF

        100:
            IF Mover1.bInPosizione THEN
                iPassoMover1 := 10;
            END_IF

    END_CASE


    // =============================================================
    // LOGICA MOVER 2
    // =============================================================
    CASE iPassoMover2 OF

        10:
            Vel_M2 := fVelocitaLavoro;
            bM2_Pronto := FALSE;
            Mover2.iRotazioneVisiva := 0;
			bM2_AbilitaRotazione := TRUE;
            IF Mover2.bInPosizione AND bStartCiclo THEN
                iPassoMover2 := 20;
            END_IF

        20:
            bSpiaLancio := TRUE;

            LancioCavo(bStartLavoro := TRUE, bMoverPronto := TRUE);
            Mover2.bChiudiPinza := LancioCavo.bRichiestaChiusuraPinza;

            IF LancioCavo.bFiloInTensione THEN
                MotoreAvvolgimento(
                    bStart          := TRUE,
                    fLunghezzaTarget:= DatiProdottoCorrente.fLunghezzaCavoTotale,
                    fVelocitaMax    := 100.0
                );
                Mover2.iRotazioneVisiva := MotoreAvvolgimento.fAngoloRotazione;
            END_IF

            IF MotoreAvvolgimento.bDone THEN
                MotoreAvvolgimento(bStart := FALSE);
                LancioCavo(bStartLavoro := FALSE);

                Mover2.iRotazioneVisiva := 0;
                bSpiaLancio := FALSE;
                iPassoMover2 := 21;
            END_IF

        21:
            bSpiaCorrezione := TRUE;

            SimulazioneCorrezione(bStart := TRUE, tDurata := T#1S);

            IF SimulazioneCorrezione.bDone THEN
                SimulazioneCorrezione(bStart := FALSE);
                bSpiaCorrezione := FALSE;
                iPassoMover2 := 22;
            END_IF

        22:
            bSpiaTaglio := TRUE;

            SimulazioneTaglio(bStart := TRUE, tDurata := T#0.5S);

            IF SimulazioneTaglio.bDone THEN
                SimulazioneTaglio(bStart := FALSE);
                bSpiaTaglio := FALSE;

                Mover2.bCaricaBobina := TRUE;
				Mover2.bPezzoPresente := TRUE;
                iPassoMover2 := 11;
            END_IF

        11:
            Mover2.bCaricaBobina := FALSE;
            bM2_Pronto := TRUE;

            IF bMuoviTutti THEN
                bM2_Pronto := FALSE;
                TargetX_M2 := 900;
                TargetY_M2 := 0;
                iPassoMover2 := 30;
            END_IF

        30:
            IF Mover2.bInPosizione THEN
                iPassoMover2 := 40;
            END_IF

  		40:
            Vel_M2 := fVelocitaLavoro;
            bM2_Pronto := FALSE;
            Mover2.bChiudiPinza := FALSE;

            RobotTransfer(bStart := TRUE, tDurata := tTempoST2);

            IF RobotTransfer.bBusy THEN    
				IF Mover2.bPezzoPresente THEN
					// SE HO FATTO IL SETUP -> Uso la mia memoria (i 45 gradi)
					IF bSetupFatto_M2 THEN
						IF Mover2.fRotazioneGruppo < iMemoriaGradi_M2 THEN  // <--- GUARDA QUI
							Mover2.fRotazioneGruppo := Mover2.fRotazioneGruppo + 1;
						END_IF
					
					// SE NON HO FATTO IL SETUP -> Uso i gradi vecchi normali
					ELSE
						IF Mover2.fRotazioneGruppo < iTargetRotazioneCorrezione THEN
							Mover2.fRotazioneGruppo := Mover2.fRotazioneGruppo + 1;
						END_IF
					END_IF
				END_IF
            END_IF

            IF RobotTransfer.bDone THEN
                RobotTransfer(bStart := FALSE);
                iPassoMover2 := 41;
            END_IF


        41:
            bM2_Pronto := TRUE;

            IF bMuoviTutti THEN
                bM2_Pronto := FALSE;
                TargetX_M2 := 0;
                TargetY_M2 := 0;
                iPassoMover2 := 50;
            END_IF

        50:
            IF Mover2.bInPosizione THEN
                iPassoMover2 := 60;
            END_IF

        60:
            Vel_M2 := fVelocitaLavoro;
            bM2_Pronto := FALSE;

            ScaricoLegatura(bStart := TRUE, tDurata := tTempoST3);

            IF ScaricoLegatura.bDone THEN
                ScaricoLegatura(bStart := FALSE);
                Mover2.bScaricaBobina := TRUE;
                iPassoMover2 := 65;
            END_IF

        65:
            IF Mover2.fRotazioneGruppo > 0 THEN
                Mover2.fRotazioneGruppo := Mover2.fRotazioneGruppo - 1;
            ELSE
				IF Mover2.bPezzoPresente THEN
					IF Mover2.bPezzoScartato THEN
						iPezziScartati := iPezziScartati + 1;
						Mover2.bPezzoScartato := FALSE;
					ELSE
						iPezziProdotti := iPezziProdotti + 1;
					END_IF
					Mover2.bPezzoPresente := FALSE;
				END_IF
				iPassoMover2 := 61;
            END_IF

        61:
            Mover2.bScaricaBobina := FALSE;
            bM2_Pronto := TRUE;

            IF bMuoviTutti THEN
                bM2_Pronto := FALSE;

                TargetX_M2 := 0;
                TargetY_M2 := 1100;
                Vel_M2 := fVelocitaRitorno;

                iPassoMover2 := 70;
            END_IF

        70:
            IF Mover2.bInPosizione THEN
                TargetX_M2 := 1500;
                TargetY_M2 := 1100;
                iPassoMover2 := 80;
            END_IF

        80:
            IF Mover2.bInPosizione THEN
                Setup_M2(bStart := FALSE);
                iPassoMover2 := 90;
            END_IF

        90:
            Vel_M2 := fVelocitaRitorno;

            // CORREZIONE QUI: Controllo bSetupFatto_M3 (non M1!)
            IF (iContatoreSetup > 0) AND (NOT bSetupFatto_M2) THEN
                
                Setup_M2(bStart := TRUE, tDurata := T#4.5S);

                IF Setup_M2.bDone THEN
                    Setup_M2(bStart := FALSE);
                    
                    // Decremento il contatore solo alla FINE
                    iContatoreSetup := iContatoreSetup - 1;
                    
                    bSetupFatto_M2 := TRUE; 
                    
                    // USO LA VARIABILE GLOBALE SICURA
                    iMemoriaGradi_M2 := iTargetFuturo;
                    
                    iPassoMover2 := 91;
                END_IF

            ELSE
                // Setup veloce (passaggio a vuoto)
                Setup_M2(bStart := TRUE, tDurata := T#0.5S);

                IF Setup_M2.bDone THEN
                    Setup_M2(bStart := FALSE);
                    iPassoMover2 := 91;
                END_IF
            END_IF

        91:
            bM2_Pronto := TRUE;

            IF bMuoviTutti THEN
                bM2_Pronto := FALSE;

                TargetX_M2 := 1500;
                TargetY_M2 := 0;
                Vel_M2 := fVelocitaRitorno;

                iPassoMover2 := 100;
            END_IF

        100:
            IF Mover2.bInPosizione THEN
                iPassoMover2 := 10;
            END_IF

    END_CASE


    // =============================================================
    // LOGICA MOVER 3
    // =============================================================
    CASE iPassoMover3 OF

        10:
            Vel_M3 := fVelocitaLavoro;
            bM3_Pronto := FALSE;
            Mover3.iRotazioneVisiva := 0;

            IF Mover3.bInPosizione AND bStartCiclo THEN
                iPassoMover3 := 20;
            END_IF

        20:
            bSpiaLancio := TRUE;

            LancioCavo(bStartLavoro := TRUE, bMoverPronto := TRUE);
            Mover3.bChiudiPinza := LancioCavo.bRichiestaChiusuraPinza;

            IF LancioCavo.bFiloInTensione THEN
                MotoreAvvolgimento(
                    bStart          := TRUE,
                    fLunghezzaTarget:= DatiProdottoCorrente.fLunghezzaCavoTotale,
                    fVelocitaMax    := 100.0
                );
                Mover3.iRotazioneVisiva := MotoreAvvolgimento.fAngoloRotazione;
            END_IF

            IF MotoreAvvolgimento.bDone THEN
                MotoreAvvolgimento(bStart := FALSE);
                LancioCavo(bStartLavoro := FALSE);

                Mover3.iRotazioneVisiva := 0;
                bSpiaLancio := FALSE;
                iPassoMover3 := 21;
            END_IF

        21:
            bSpiaCorrezione := TRUE;

            SimulazioneCorrezione(bStart := TRUE, tDurata := T#1S);

            IF SimulazioneCorrezione.bDone THEN
                SimulazioneCorrezione(bStart := FALSE);
                bSpiaCorrezione := FALSE;
                iPassoMover3 := 22;
            END_IF

        22:
            bSpiaTaglio := TRUE;

            SimulazioneTaglio(bStart := TRUE, tDurata := T#0.5S);

            IF SimulazioneTaglio.bDone THEN
                SimulazioneTaglio(bStart := FALSE);
                bSpiaTaglio := FALSE;

                Mover3.bCaricaBobina := TRUE;
				Mover3.bPezzoPresente := TRUE;
                iPassoMover3 := 11;
            END_IF

        11:
            Mover3.bCaricaBobina := FALSE;
            bM3_Pronto := TRUE;

            IF bMuoviTutti THEN
                bM3_Pronto := FALSE;
                TargetX_M3 := 900;
                TargetY_M3 := 0;
                iPassoMover3 := 30;
            END_IF

        30:
            IF Mover3.bInPosizione THEN
                iPassoMover3 := 40;
            END_IF

		40:
            Vel_M3 := fVelocitaLavoro;
            bM3_Pronto := FALSE;
            Mover3.bChiudiPinza := FALSE;

            RobotTransfer(bStart := TRUE, tDurata := tTempoST2);

            IF RobotTransfer.bBusy THEN
                
                // SE HO FATTO IL SETUP -> Uso la mia memoria 
                IF bSetupFatto_M3 THEN
                    IF Mover3.fRotazioneGruppo < iMemoriaGradi_M3 THEN  // <--- GUARDA QUI
                        Mover3.fRotazioneGruppo := Mover3.fRotazioneGruppo + 1;
                    END_IF
                
                // SE NON HO FATTO IL SETUP -> Uso i gradi vecchi normali
                ELSE
                    IF Mover3.fRotazioneGruppo < iTargetRotazioneCorrezione THEN
                        Mover3.fRotazioneGruppo := Mover3.fRotazioneGruppo + 1;
                    END_IF
                END_IF

            END_IF

            IF RobotTransfer.bDone THEN
                RobotTransfer(bStart := FALSE);
                iPassoMover3 := 41;
            END_IF

        41:
            bM3_Pronto := TRUE;

            IF bMuoviTutti THEN
                bM3_Pronto := FALSE;
                TargetX_M3 := 0;
                TargetY_M3 := 0;
                iPassoMover3 := 50;
            END_IF

        50:
            IF Mover3.bInPosizione THEN
                iPassoMover3 := 60;
            END_IF

        60:
            Vel_M3 := fVelocitaLavoro;
            bM3_Pronto := FALSE;

            ScaricoLegatura(bStart := TRUE, tDurata := tTempoST3);

            IF ScaricoLegatura.bDone THEN
                ScaricoLegatura(bStart := FALSE);
                Mover3.bScaricaBobina := TRUE;
                iPassoMover3 := 65;
            END_IF

        65:
            IF Mover3.fRotazioneGruppo > 0 THEN
                Mover3.fRotazioneGruppo := Mover3.fRotazioneGruppo - 1;
            ELSE
				IF Mover3.bPezzoPresente THEN
					IF Mover3.bPezzoScartato THEN
						iPezziScartati := iPezziScartati + 1;
						Mover3.bPezzoScartato := FALSE;
					ELSE
						iPezziProdotti := iPezziProdotti + 1;
					END_IF
					Mover3.bPezzoPresente := FALSE;
				END_IF
				iPassoMover3 := 61;
            END_IF

        61:
            Mover3.bScaricaBobina := FALSE;
            bM3_Pronto := TRUE;

            IF bMuoviTutti THEN
                bM3_Pronto := FALSE;

                TargetX_M3 := 0;
                TargetY_M3 := 1100;
                Vel_M3 := fVelocitaRitorno;

                iPassoMover3 := 70;
            END_IF

        70:
            IF Mover3.bInPosizione THEN
                TargetX_M3 := 1500;
                TargetY_M3 := 1100;
                iPassoMover3 := 80;
            END_IF

        80:
            IF Mover3.bInPosizione THEN
                Setup_M3(bStart := FALSE);
                iPassoMover3 := 90;
            END_IF

 		90:
            Vel_M3 := fVelocitaRitorno;

            // CORREZIONE QUI: Controllo bSetupFatto_M3 (non M1!)
            IF (iContatoreSetup > 0) AND (NOT bSetupFatto_M3) THEN
                
                Setup_M3(bStart := TRUE, tDurata := T#4.5S);

                IF Setup_M3.bDone THEN
                    Setup_M3(bStart := FALSE);
                    
                    // Decremento il contatore solo alla FINE
                    iContatoreSetup := iContatoreSetup - 1;
                    
                    bSetupFatto_M3 := TRUE; 
                    
                    // USO LA VARIABILE GLOBALE SICURA
                    iMemoriaGradi_M3 := iTargetFuturo;
                    
                    iPassoMover3 := 91;
                END_IF

            ELSE
                // Setup veloce (passaggio a vuoto)
                Setup_M3(bStart := TRUE, tDurata := T#0.5S);

                IF Setup_M3.bDone THEN
                    Setup_M3(bStart := FALSE);
                    iPassoMover3 := 91;
                END_IF
            END_IF

        91:
            bM3_Pronto := TRUE;

            IF bMuoviTutti THEN
                bM3_Pronto := FALSE;

                TargetX_M3 := 1500;
                TargetY_M3 := 0;
                Vel_M3 := fVelocitaRitorno;

                iPassoMover3 := 100;
            END_IF

        100:
            IF Mover3.bInPosizione THEN
                iPassoMover3 := 10;
            END_IF

    END_CASE


    // =============================================================
    // LOGICA MOVER 4
    // =============================================================
    CASE iPassoMover4 OF

        10:
            Vel_M4 := fVelocitaLavoro;
            bM4_Pronto := FALSE;
            Mover4.iRotazioneVisiva := 0;

            IF Mover4.bInPosizione AND bStartCiclo THEN
                iPassoMover4 := 20;
            END_IF

        20:
            bSpiaLancio := TRUE;

            LancioCavo(bStartLavoro := TRUE, bMoverPronto := TRUE);
            Mover4.bChiudiPinza := LancioCavo.bRichiestaChiusuraPinza;

            IF LancioCavo.bFiloInTensione THEN
                MotoreAvvolgimento(
                    bStart          := TRUE,
                    fLunghezzaTarget:= DatiProdottoCorrente.fLunghezzaCavoTotale,
                    fVelocitaMax    := 100.0
                );
                Mover4.iRotazioneVisiva := MotoreAvvolgimento.fAngoloRotazione;
            END_IF

            IF MotoreAvvolgimento.bDone THEN
                MotoreAvvolgimento(bStart := FALSE);
                LancioCavo(bStartLavoro := FALSE);

                Mover4.iRotazioneVisiva := 0;
                bSpiaLancio := FALSE;
                iPassoMover4 := 21;
            END_IF

        21:
            bSpiaCorrezione := TRUE;

            SimulazioneCorrezione(bStart := TRUE, tDurata := T#1S);

            IF SimulazioneCorrezione.bDone THEN
                SimulazioneCorrezione(bStart := FALSE);
                bSpiaCorrezione := FALSE;
                iPassoMover4 := 22;
            END_IF

        22:
            bSpiaTaglio := TRUE;

            SimulazioneTaglio(bStart := TRUE, tDurata := T#0.5S);

            IF SimulazioneTaglio.bDone THEN
                SimulazioneTaglio(bStart := FALSE);
                bSpiaTaglio := FALSE;

                Mover4.bCaricaBobina := TRUE;
				Mover4.bPezzoPresente := TRUE;
                iPassoMover4 := 11;
            END_IF

        11:
            Mover4.bCaricaBobina := FALSE;
            bM4_Pronto := TRUE;

            IF bMuoviTutti THEN
                bM4_Pronto := FALSE;
                TargetX_M4 := 900;
                TargetY_M4 := 0;
                iPassoMover4 := 30;
            END_IF

        30:
            IF Mover4.bInPosizione THEN
                iPassoMover4 := 40;
            END_IF

         40:
            Vel_M4 := fVelocitaLavoro;
            bM4_Pronto := FALSE;
            Mover4.bChiudiPinza := FALSE;

            RobotTransfer(bStart := TRUE, tDurata := tTempoST2);

            IF RobotTransfer.bBusy THEN
                
                // SE HO FATTO IL SETUP -> Uso la mia memoria (i 45 gradi)
                IF bSetupFatto_M4 THEN
                    IF Mover4.fRotazioneGruppo < iMemoriaGradi_M4 THEN  // <--- GUARDA QUI
                        Mover4.fRotazioneGruppo := Mover4.fRotazioneGruppo + 1;
                    END_IF
                
                // SE NON HO FATTO IL SETUP -> Uso i gradi vecchi normali
                ELSE
                    IF Mover4.fRotazioneGruppo < iTargetRotazioneCorrezione THEN
                        Mover4.fRotazioneGruppo := Mover4.fRotazioneGruppo + 1;
                    END_IF
                END_IF

            END_IF

            IF RobotTransfer.bDone THEN
                RobotTransfer(bStart := FALSE);
                iPassoMover4 := 41;
            END_IF

        41:
            bM4_Pronto := TRUE;

            IF bMuoviTutti THEN
                bM4_Pronto := FALSE;
                TargetX_M4 := 0;
                TargetY_M4 := 0;
                iPassoMover4 := 50;
            END_IF

        50:
            IF Mover4.bInPosizione THEN
                iPassoMover4 := 60;
            END_IF

        60:
            Vel_M4 := fVelocitaLavoro;
            bM4_Pronto := FALSE;

            ScaricoLegatura(bStart := TRUE, tDurata := tTempoST3);

            IF ScaricoLegatura.bDone THEN
                ScaricoLegatura(bStart := FALSE);
                Mover4.bScaricaBobina := TRUE;
                iPassoMover4 := 65;
            END_IF

        65:
            IF Mover4.fRotazioneGruppo > 0 THEN
                Mover4.fRotazioneGruppo := Mover4.fRotazioneGruppo - 1;
            ELSE
				IF Mover4.bPezzoPresente THEN
					IF Mover4.bPezzoScartato THEN
						iPezziScartati := iPezziScartati + 1;
						Mover4.bPezzoScartato := FALSE;
					ELSE
						iPezziProdotti := iPezziProdotti + 1;
					END_IF
					Mover4.bPezzoPresente := FALSE;
				END_IF
				iPassoMover4 := 61;
            END_IF

        61:
            Mover4.bScaricaBobina := FALSE;
            bM4_Pronto := TRUE;

            IF bMuoviTutti THEN
                bM4_Pronto := FALSE;

                TargetX_M4 := 0;
                TargetY_M4 := 1100;
                Vel_M4 := fVelocitaRitorno;

                iPassoMover4 := 70;
            END_IF

        70:
            IF Mover4.bInPosizione THEN
                TargetX_M4 := 1500;
                TargetY_M4 := 1100;
                iPassoMover4 := 80;
            END_IF

        80:
            IF Mover4.bInPosizione THEN
                Setup_M4(bStart := FALSE);
                iPassoMover4 := 90;
            END_IF

        90:
            Vel_M4 := fVelocitaRitorno;

            // CORREZIONE QUI: Controllo bSetupFatto_M3 (non M1!)
            IF (iContatoreSetup > 0) AND (NOT bSetupFatto_M4) THEN
                
                Setup_M4(bStart := TRUE, tDurata := T#4.5S);

                IF Setup_M4.bDone THEN
                    Setup_M4(bStart := FALSE);
                    
                    // Decremento il contatore solo alla FINE
                    iContatoreSetup := iContatoreSetup - 1;
                    
                    bSetupFatto_M4 := TRUE; 
                    
                    // USO LA VARIABILE GLOBALE SICURA
                    iMemoriaGradi_M4 := iTargetFuturo;
                    
                    iPassoMover4 := 91;
                END_IF

            ELSE
                // Setup veloce (passaggio a vuoto)
                Setup_M4(bStart := TRUE, tDurata := T#0.5S);

                IF Setup_M4.bDone THEN
                    Setup_M4(bStart := FALSE);
                    iPassoMover4 := 91;
                END_IF
            END_IF

        91:
            bM4_Pronto := TRUE;

            IF bMuoviTutti THEN
                bM4_Pronto := FALSE;

                TargetX_M4 := 1500;
                TargetY_M4 := 0;
                Vel_M4 := fVelocitaRitorno;

                iPassoMover4 := 100;
            END_IF

        100:
            IF Mover4.bInPosizione THEN
                iPassoMover4 := 10;
            END_IF

    END_CASE

ELSE
	// =========================================================
    // GESTIONE "FREEZE" (EMERGENZA ATTIVA)
    // =========================================================
    
    // 1. Fermo i Motori (Velocità a 0)
    Vel_M1 := 0; Vel_M2 := 0; Vel_M3 := 0; Vel_M4 := 0;
    
	// QUESTE CHE CI SONO QUI TUTTE COMMENTATE NON SO SE SERVANO O MENO PER GESTIRE LA FERMATA DI EMERGENZA!!!!///
    // 2. RESETTO I BLOCCHI FUNZIONALI (Timer)
    // Questo è fondamentale: se non li chiamo con FALSE durante l'emergenza,
    // quando riparto potrebbero essere "incantati" o aver perso il conteggio.
    // Resettandoli, al riavvio ripartiranno da capo (sicurezza).
    
    //RobotTransfer(bStart := FALSE);
    //ScaricoLegatura(bStart := FALSE);
    
    //Setup_M1(bStart := FALSE);
    //Setup_M2(bStart := FALSE);
    //Setup_M3(bStart := FALSE);
    //Setup_M4(bStart := FALSE);
    
    //SimulazioneCorrezione(bStart := FALSE);
    //SimulazioneTaglio(bStart := FALSE);
    //LancioCavo(bStartLavoro := FALSE);

END_IF // FINE IF NOT bEmergenzaAttiva

// =============================================================
// CHIAMATE ISTANZE
// =============================================================
MotoreAvvolgimento(
    bStart     := (iPassoMover1 = 20) OR (iPassoMover2 = 20) OR (iPassoMover3 = 20) OR (iPassoMover4 = 20),
    bEmergenza := bEmergenzaAttiva
);

Mover1(
    fTargetX           := TargetX_M1,
    fTargetY           := TargetY_M1,
    fVelocita          := Vel_M1,
    bAbilitaMovimento  := TRUE,
    bInizializza       := Mover1.bInizializza,
    fInitX             := Mover1.fInitX,
    fInitY             := Mover1.fInitY,
    bChiudiPinza       := Mover1.bChiudiPinza,
    bCaricaBobina      := Mover1.bCaricaBobina,
    bScaricaBobina     := Mover1.bScaricaBobina,
    iRotazioneVisiva   := Mover1.iRotazioneVisiva,
    fRotazioneGruppo   := Mover1.fRotazioneGruppo,
    bPezzoScartato     := Mover1.bPezzoScartato
);

Mover2(
    fTargetX           := TargetX_M2,
    fTargetY           := TargetY_M2,
    fVelocita          := Vel_M2,
    bAbilitaMovimento  := TRUE,
    bInizializza       := Mover2.bInizializza,
    fInitX             := Mover2.fInitX,
    fInitY             := Mover2.fInitY,
    bChiudiPinza       := Mover2.bChiudiPinza,
    bCaricaBobina      := Mover2.bCaricaBobina,
    bScaricaBobina     := Mover2.bScaricaBobina,
    iRotazioneVisiva   := Mover2.iRotazioneVisiva,
    fRotazioneGruppo   := Mover2.fRotazioneGruppo,
    bPezzoScartato     := Mover2.bPezzoScartato
);

Mover3(
    fTargetX           := TargetX_M3,
    fTargetY           := TargetY_M3,
    fVelocita          := Vel_M3,
    bAbilitaMovimento  := TRUE,
    bInizializza       := Mover3.bInizializza,
    fInitX             := Mover3.fInitX,
    fInitY             := Mover3.fInitY,
    bChiudiPinza       := Mover3.bChiudiPinza,
    bCaricaBobina      := Mover3.bCaricaBobina,
    bScaricaBobina     := Mover3.bScaricaBobina,
    iRotazioneVisiva   := Mover3.iRotazioneVisiva,
    fRotazioneGruppo   := Mover3.fRotazioneGruppo,
    bPezzoScartato     := Mover3.bPezzoScartato
);

Mover4(
    fTargetX           := TargetX_M4,
    fTargetY           := TargetY_M4,
    fVelocita          := Vel_M4,
    bAbilitaMovimento  := TRUE,
    bInizializza       := Mover4.bInizializza,
    fInitX             := Mover4.fInitX,
    fInitY             := Mover4.fInitY,
    bChiudiPinza       := Mover4.bChiudiPinza,
    bCaricaBobina      := Mover4.bCaricaBobina,
    bScaricaBobina     := Mover4.bScaricaBobina,
    iRotazioneVisiva   := Mover4.iRotazioneVisiva,
    fRotazioneGruppo   := Mover4.fRotazioneGruppo,
    bPezzoScartato     := Mover4.bPezzoScartato
);
