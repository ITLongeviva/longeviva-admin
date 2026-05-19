# Longeviva Admin — Riepilogo modifiche

Branch: `claude/admin-panel-modifications-NbMRm`  
Periodo: 7–9 maggio 2026  
Totale righe aggiunte: ~3.300 (su 4 sessioni di lavoro)

---

## Panoramica commit

| Commit | Data | Descrizione |
|--------|------|-------------|
| `1e54c13` | 7 mag | Cluster cards uniformi + dialog dettaglio |
| `4fea5b1` | 7 mag | Tab per figura (dottori) + cerchie affinità (pazienti) |
| `d8487d2` | 9 mag | Matching engine + completezza profilo + churn risk |
| `78e71c7` | 9 mag | Bulk actions signup + audit log admin |

---

## 1. Cluster cards uniformi e cliccabili

**File:** `doctors_large_screen_view_model.dart`, `patients_large_screen_view_model.dart`

### Prima
Le card dei cluster erano rese con `Wrap + SizedBox` a dimensione variabile, non cliccabili.

### Dopo
- `GridView.builder` con `SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 380, mainAxisExtent: 210)` → tutte le card hanno la stessa altezza
- Layout compatto: intestazione colorata con icona e titolo, `LinearProgressIndicator` da 4px, riga con 3 statistiche, footer "Vedi dettagli →"
- `Card` con `clipBehavior: Clip.antiAlias` + `InkWell` per il tap
- **Dialog dettaglio** (`showDialog` + `StatefulBuilder`): larghezza 720px, stats aggregate, campo di ricerca, lista scrollabile dei membri

**Dottori — dialog mostra:** avatar, nome/email, ruoli, città, tariffa oraria, età, icona setup  
**Pazienti — dialog mostra:** avatar, nome/email, sesso, età, città, chip condizioni (max 2), icone dottore/onboarding

---

## 2. Tab "Per figura" — Schermata Dottori

**File:** `doctors_large_screen_view_model.dart`

Nuova voce `'figura'` nel submenu della schermata dottori.

### Contenuto per ogni ruolo (Nutrizionista / Personal Trainer / Psicologo)
- **KPI row:** conteggio, tariffa media, età media, % setup completato, numero iscritti/tesserati
- **Distribuzione specialità** (`specialty`) — barre orizzontali con conteggio
- **Area di interesse** (`areaOfInterest`) — stessa struttura
- **Top città di lavoro**
- **Lingue parlate** (`languagesSpoken`)
- **Enti/università issuers** (`issuer`)
- Stato vuoto "dato non compilato" su ogni sezione mancante

**Selector tab animato** con badge contatore per ruolo.

---

## 3. Cerchie di affinità — Schermata Pazienti

**File:** `patients_large_screen_view_model.dart`

Nuova voce `'cerchie'` nel submenu della schermata pazienti.

### Logica di raggruppamento
Pazienti raggruppati per `condizione × fascia d'età` (min 2 membri, max 24 cerchie visibili).

### Visualizzazione
- **Bubble chart** con container circolari: diametro = `90 + (count/maxCount) × 90` px, colore deterministico via `condition.hashCode.abs() % colors.length`
- Tap su bolla → dialog anonimo con 6 stat aggregate (totale, con dottore, onboarding completato, età media, distribuzione sesso, % attivi)
- **Disclaimer privacy** nel dialog
- Tabella riepilogativa sotto i bubble

---

## 4. Matching engine — Schermata Analytics

**File:** `platform_analytics_large_screen_view_model.dart`

Nuova sezione nella schermata Platform Analytics che incrocia pazienti senza dottore e dottori senza pazienti.

### Getter aggiunti a `_Content`
```dart
Map<String, int> get _patientCountPerDoctor     // pazienti per dottore
List<Doctor> get _doctorsWithNoPatients          // dottori con 0 pazienti
List<Patient> get _unassignedPatients            // pazienti senza assignedDoctorId
List<({String city, int patients, int doctors, List<String> roles})>
    get _cityMatchOpportunities                  // top 10 città per opportunità
```

### UI `_matchingEngineSection()`
- **KPI row:** pazienti non assegnati, dottori liberi, % assegnati, città con match
- **Due colonne:** lista pazienti non assegnati (avatar, nome, città, badge giorni) + lista dottori disponibili (avatar, nome, ruoli, città)
- **Tabella città:** Città | Paz. in attesa | Prof. liberi | Ruoli (chip colorati) | Stato ("Match!" verde / "In attesa" arancione)

---

## 5. Completezza profilo dottori

**File:** `doctors_large_screen_view_model.dart`

Nuova sezione mostrata nella vista lista (`_viewMode == 'lista'`).

### Scoring
5 campi valutati: `specialty`, `areaOfInterest`, `languagesSpoken` (non vuoto), `issuer`, `qualificationValidity`.  
Score: 0–5 → convertito in percentuale.

### UI `_profileCompletenessSection()`
- **Badge media globale** colorato: verde ≥80%, arancione ≥50%, rosso <50%
- **Pannello sinistro:** 5 barre fill-rate (quanti dottori hanno compilato ogni campo)
- **Pannello destro:** lista profili incompleti (<60%), ordinati per score crescente

---

## 6. Pazienti a rischio churn

**File:** `patients_large_screen_view_model.dart`

Nuova sezione mostrata in cima alla schermata pazienti (sopra il submenu).

### Logica `_churnRiskPatients`
Pazienti **senza dottore assegnato** AND:
- `lastActivityAt` > 30 giorni fa, **oppure**
- `lastActivityAt == null` AND `createdAt` > 14 giorni fa

Ordinati per data attività più vecchia prima.

### UI `_churnRiskSection()`
- Icona warning + badge rosso con conteggio
- Fino a 8 righe: avatar colorato per gravità, nome, città, preview condizioni, badge "N gg inattivo"
- **Colori:** rosso >60 gg, arancione >30 gg, ambra altrimenti

---

## 7. Bulk actions — Richieste di signup

**File:** `signup_requests_large_screen_view_model.dart`

### Selezione multipla
- `Set<String> _selectedIds` gestisce gli ID selezionati
- **Checkbox** aggiunto a sinistra del badge stato su ogni card `pending`
- **Action bar** (visibile quando `_selectedIds.isNotEmpty`):
  - Tristate checkbox "seleziona tutti i pending filtrati"
  - Counter "N selezionate"
  - Pulsante "Deseleziona"
  - Pulsante "Rifiuta" (outline rosso)
  - Pulsante "Approva" (filled verde)

### Dialog approvazione bulk
- Mostra conteggio richieste selezionate
- `PasswordValidationWidget` per password temporanea condivisa (rigenerabile)
- Dispatcha `BatchApproveSignupRequests(requestIds, defaultPassword)`

### Dialog rifiuto bulk
- Campo motivo opzionale condiviso
- Dispatcha `BatchRejectSignupRequests(requestIds, reason)`

### Backend aggiunto
- `BatchRejectSignupRequests` event + `SignupRequestsBatchRejected` state nel BLoC
- `batchRejectSignupRequests` nel controller e nel repository (loop su `rejectSignupRequestWithReason`)

---

## 8. Audit log admin

### Nuovi file

#### `lib/backend/models/admin_action_model.dart`
```dart
class AdminAction {
  final String id;
  final String adminEmail;
  final String adminName;
  final String action;     // 'approve' | 'reject' | 'batch_approve' | 'batch_reject'
  final String? requestId;
  final String? requestName;
  final String? notes;
  final DateTime timestamp;
  final int? batchCount;
}
```

#### `lib/backend/repositories/audit_log_repository.dart`
- Collezione Firestore: `admin_actions`
- `logAction({...})` — scrive con `FieldValue.serverTimestamp()`
- `getRecentActions({int limit = 30})` — query ordinata per `timestamp` decrescente

#### `lib/backend/bloc/audit_log_bloc.dart`
- Event: `FetchRecentAdminActions`
- States: `AuditLogInitial`, `AuditLogLoading`, `AuditLogLoaded(List<AdminAction>)`, `AuditLogError`
- **Auto-fetch alla creazione** del BLoC

### Modifiche esistenti

**`signup_request_bloc.dart`** — dopo ogni `emit(SignupRequestApproved/Rejected/BatchApproved)` chiama `AuditLogRepository().logAction(...)` usando `FirebaseAuth.instance.currentUser` per l'identità.

**`main.dart`** — aggiunto `BlocProvider<AuditLogBloc>` nel `MultiBlocProvider`.

### UI — "Attività recente" nella Home Dashboard

**File:** `admin_dashboard_home_large_screen_view_model.dart`

Nuova card `BlocBuilder<AuditLogBloc, AuditLogState>` in fondo alla home, visibile solo quando ci sono azioni.

Ogni voce mostra:
- Icona circolare colorata (verde = approvazione, rosso = rifiuto)
- `adminName · azione` + timestamp relativo ("Xm fa" / "Xh fa" / "Xg fa")
- Nome richiedente (se presente)
- Note/motivo (se presenti, in corsivo)

---

## File modificati — riepilogo completo

| File | Tipo | Modifica |
|------|------|----------|
| `view_model/doctors_large_screen_view_model.dart` | Modificato | Cluster cards, tab figura, completezza profilo |
| `view_model/patients_large_screen_view_model.dart` | Modificato | Cluster cards, cerchie affinità, churn risk |
| `view_model/platform_analytics_large_screen_view_model.dart` | Modificato | Matching engine |
| `view_model/signup_requests_large_screen_view_model.dart` | Modificato | Bulk actions UI |
| `view_model/admin_dashboard_home_large_screen_view_model.dart` | Modificato | Audit log timeline |
| `backend/bloc/signup_request_bloc.dart` | Modificato | BatchReject + audit log calls |
| `backend/bloc/audit_log_bloc.dart` | **Nuovo** | AuditLogBloc |
| `backend/models/admin_action_model.dart` | **Nuovo** | AdminAction model |
| `backend/repositories/audit_log_repository.dart` | **Nuovo** | AuditLogRepository |
| `backend/controllers/signup_request_controller.dart` | Modificato | batchRejectSignupRequests |
| `backend/repositories/signup_request_repository.dart` | Modificato | batchRejectSignupRequests |
| `lib/main.dart` | Modificato | AuditLogBloc provider |
