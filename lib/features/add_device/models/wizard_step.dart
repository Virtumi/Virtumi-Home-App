enum WizardStep {
  password,
  searchType,
  lanScan,
  btPick,
  btWifi,
  btWait,
  btResolve,

  /// The discovered device already belongs to an account (owner info + options).
  deviceClaimed,
  location,
  dateTime,
  general,
  update,
  passwordOpt,
  supabase,
  credentials,
  done,
}

extension WizardStepX on WizardStep {
  String get title => switch (this) {
    WizardStep.password => 'Geräte-Passwort',
    WizardStep.searchType => 'Suchart',
    WizardStep.lanScan => 'Netzwerk scannen',
    WizardStep.btPick => 'Bluetooth-Gerät',
    WizardStep.btWifi => 'WLAN konfigurieren',
    WizardStep.btWait => 'WLAN-Verbindung',
    WizardStep.btResolve => 'IP ermitteln',
    WizardStep.deviceClaimed => 'Gerät bereits verknüpft',
    WizardStep.location => 'Standort',
    WizardStep.dateTime => 'Datum & Uhrzeit',
    WizardStep.general => 'Allgemein',
    WizardStep.update => 'Update',
    WizardStep.passwordOpt => 'Passwort ändern',
    WizardStep.supabase => 'In Supabase speichern',
    WizardStep.credentials => 'Cloud-Anmeldedaten',
    WizardStep.done => 'Fertig',
  };

  bool get canGoBack => this != WizardStep.done;

  WizardStep? get previous => switch (this) {
    WizardStep.password => null,
    WizardStep.searchType => WizardStep.password,
    WizardStep.lanScan => WizardStep.searchType,
    WizardStep.btPick => WizardStep.searchType,
    WizardStep.btWifi => WizardStep.btPick,
    WizardStep.btWait => WizardStep.btWifi,
    WizardStep.btResolve => WizardStep.btWait,
    WizardStep.deviceClaimed => null, // set by controller based on path
    WizardStep.location => null, // set by controller based on path
    WizardStep.dateTime => WizardStep.location,
    WizardStep.general => WizardStep.dateTime,
    WizardStep.update => WizardStep.general,
    WizardStep.passwordOpt => WizardStep.update,
    WizardStep.supabase => WizardStep.passwordOpt,
    WizardStep.credentials => WizardStep.supabase,
    WizardStep.done => WizardStep.credentials,
  };
}
