enum IncidentType {
  escalator('Escada rolante'),
  elevator('Elevador'),
  ticketMachine('Maquina de bilhetes'),
  turnstile('Torniquete'),
  other('Outro');

  final String displayName;

  const IncidentType(this.displayName);

  // Compatibilidade com os testes antigos dos professores.
  // ignore: constant_identifier_names
  static const IncidentType Escalator = escalator;
  // ignore: constant_identifier_names
  static const IncidentType Elevator = elevator;
  // ignore: constant_identifier_names
  static const IncidentType TicketMachine = ticketMachine;
  // ignore: constant_identifier_names
  static const IncidentType Turnstile = turnstile;
  // ignore: constant_identifier_names
  static const IncidentType Other = other;
}

class IncidentReport {
  final DateTime timestamp;
  final int rate;
  final String? notes;
  final IncidentType type;

  IncidentReport({
    required this.timestamp,
    required this.rate,
    this.notes,
    required this.type,
  });
}
