abstract final class AppStrings {
  static const String appName = 'SaúdeKonekta';
  static const String loginTagline = 'Platafórma saúde';
  static const String signInPrompt = 'Heve login ba reviza kazu no referália.';
  static const String username = 'Utilizador';
  static const String password = 'Sandu';
  static const String login = 'Login';
  static const String invalidCredentials =
      'Utilizador ka sandu trókadu. Tenta mai fali.';
  static const String connectionError = "La' koneta servidór. Tenta fali ketiak.";
  static const String loading = "He'in...";
  static const String logout = 'Sai';
  static const String roleLabel = 'Papel';
  static const String tabOverview = 'Resumen';
  static const String tabEmergencies = 'Emergensia';
  static const String tabReferrals = 'Referália';
  static const String tabPatients = 'Pazientis';
  static const String placeholderTitle = "Iha ne'e sei prencheu iha passu oin.";
  static const String requiredFields = 'Preensi utilizador no sandu.';
  static const String roleSystemAdmin = 'Administradór sistéma';
  static const String roleDoctor = 'Doutór';
  static const String roleHealthWorker = 'Trabaladór saúde';

  static const String patientsTitle = 'Pazientis';
  static const String searchHint = 'Buka liu husi ID paziente ka naran';
  static const String searchEmpty = "La'es paziente konet ho bukaian ida";
  static const String searchEmptyHint = 'Rejista ID paziente ka tenta seluk.';
  static const String listEmpty = "La'os paziente tan";
  static const String listEmptyHint =
      "Pazientis inskrevu husi fatin sei hatudu iha ne'e lia husu.";
  static const String backToPatients = 'Fila ba pazientis';
  static const String patientRecord = 'Rekordi paziente';
  static const String identity = 'Identidade';
  static const String contact = 'Kontaktu';
  static const String location = 'Lojasau';
  static const String firstName = 'Primeiru naran';
  static const String lastName = 'Últimu naran';
  static const String dateOfBirth = 'Data nascimentu';
  static const String sex = 'Sexu';
  static const String phone = 'Telefone';
  static const String address = 'Endresu';
  static const String emergencyContact = 'Kontaktu emergensia';
  static const String patientId = 'ID paziente';
  static const String ageGroup = 'Grupu idade';
  static const String suco = 'Suco';
  static const String adminPost = 'Postu administrativu';
  static const String municipality = 'Munisípiu';
  static const String registered = 'Inskrebe';
  static const String male = 'Mane';
  static const String female = 'Feto';
  static const String other = 'Lain';
  static const String inactiveRecord = "Rekordi ne'e la'ativu.";
  static const String monitoringRecords = 'Rekordis monitorizasaun';
  static const String monitoringEmpty = "La'os rekordi monitorizasaun";
  static const String monitoringEmptyHint =
      "Observasaun gravadu husi fatin sei hatudu iha ne'e lia husu.";
  static const String observed = 'Observa';
  static const String observedAt = 'Observadu iha';
  static const String temperature = 'Temperatura (°C)';
  static const String heartRate = 'Ritmu koração (bpm)';
  static const String respiratoryRate = 'Ritmu respira';
  static const String bpSystolic = 'BP sistóliku';
  static const String bpDiastolic = 'BP diastóliku';
  static const String spo2 = 'SpO₂ (%)';
  static const String symptoms = 'Sintomas';
  static const String notes = 'Notas';
  static const String recordedBy = 'Husi';
  static const String loadMore = 'Hataki ba oin';
  static const String retry = 'Tenta fali';

  static String roleDisplayName(String role) {
    switch (role) {
      case 'SYSTEM_ADMIN':
        return roleSystemAdmin;
      case 'DOCTOR':
        return roleDoctor;
      case 'HEALTH_WORKER':
        return roleHealthWorker;
      default:
        return role;
    }
  }

  static const String addPatient = 'Paziente foun';
  static const String addMonitoring = 'Observasaun foun';
  static const String locationPickerHint = 'Filia lokasaun';
  static const String requiredField = "Preensi fatin ida ne'e.";
  static const String dobInFuture = "Data nascimentu la' bala futuru.";
  static const String phoneInvalid = "Telefone tenke fokaan númerus + - ( ) de'it";
  static const String vitalOutOfRange = "Valoru iha ne'é la' tenke.";
  static const String patientCreated = 'Paziente registadu.';
  static const String monitoringCreated = 'Observasaun registadu.';
  static const String genericError = "Iha erro na'in. Rejista fali.";
  static const String save = 'Regista';

static const String emergenciesTitle = 'Emergensia';
  static const String newEmergency = 'Kazu foun';
  static const String emergenciesEmpty = "La'os kazu emergensia";
  static const String emergenciesEmptyHint = "Kazu foun sei hatudu iha ne'e.";
  static const String statusAll = 'Hotu';
  static const String severity = 'Gravidade';
  static const String description = 'Deskrisaun';
  static const String pickPatient = 'Hili paziente';
  static const String patientLabel = 'Paziente';
  static const String emergencyCreated = 'Kazu emergensia registadu.';
  static const String emergencySymptomsRequired = "Preensi sintomas.";
  static const String patientPickerHint = 'Buka paziente ba kazu';

  static const String referralsTitle = 'Referália';
  static const String newReferral = 'Referália foun';
  static const String referralsEmpty = "La'os referália";
  static const String referralsEmptyHint = "Referália foun sei hatudu iha ne'e.";
  static const String urgency = 'Urjénsia';
  static const String reason = 'Rezaun';
  static const String destinationFacility = 'Fasilitade destino';
  static const String sourceFacility = 'Fasilitade orijen';
  static const String selectFacility = 'Hili fasilitade';
  static const String referralCreated = 'Referália registadu.';
  static const String reasonRequired = "Preensi rezaun.";
  static const String facilityRequired = "Hili fasilitade destino ida.";
  static const String facilitiesError = "La' konsege karrega fasilitades.";

  static const String overviewTitle = 'Resumen';
  static const String overviewSubtitle = 'Visão jeral';
  static const String statPatients = 'Pazientis';
  static const String statOpenEmergencies = 'Emergensia OPEN';
  static const String statPendingReferrals = 'Referália PENDING';
  static const String overviewError = "La' konsege karrega resumen.";

  static const String syncTitle = 'Sinkronizasaun';
  static const String syncTooltip = 'Sinkronizasaun';
  static const String syncPendingLabel = 'PENDING SYNC';
  static const String syncFailedLabel = 'SYNC FAILED';
  static const String syncLastSyncedLabel = 'Synk ikus';
  static const String syncNeverLabel = 'NEVER SYNCED';
  static const String syncNow = 'Sinkroniza agora';
  static const String syncRetryFailed = "Tenta fali sira ne'ebé falha";
  static const String syncInProgress = 'Halo sinkronizasaun...';
  static const String syncComplete = 'Sinkronizasaun hotu.';
  static const String syncOfflineNotice =
      "La' online. Rejistu sira sei synk bainhira koneta.";
  static const String syncEmpty = "La' iha dadus atu synk.";
}
