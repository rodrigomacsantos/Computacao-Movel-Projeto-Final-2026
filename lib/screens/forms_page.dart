import 'package:cmproject/data/metro_repository.dart';
import 'package:cmproject/data/sqflite_metro_datasource.dart';
import 'package:cmproject/models/incident_report.dart';
import 'package:cmproject/models/station.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:testable_form_field/testable_form_field.dart';

class FormsPage extends StatefulWidget {
  const FormsPage({super.key});

  @override
  State<FormsPage> createState() => _FormsPageState();
}

class _FormsPageState extends State<FormsPage> {
  final _formKey = GlobalKey<FormState>();
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  Station? _selectedStation;
  IncidentType? _selectedIncidentType;
  int? _rating;
  DateTime? _dateTime;
  String _notes = '';

  Future<void> _pickDateTime(dynamic state) async {
    final current = _dateTime ?? DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );

    if (pickedTime == null || !mounted) {
      return;
    }

    final selectedDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    state.didChange(selectedDateTime);
    setState(() {
      _dateTime = selectedDateTime;
    });
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<MetroRepository>();
    final stations = repository.getAllStations();

    return Scaffold(
      key: const Key('incidents-report-screen'),
      appBar: AppBar(title: const Text('Registo de incidentes')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Preenche os campos para registar um incidente numa estacao.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TestableFormField<Station>(
                key: const Key('incident-station-selection-field'),
                getValue: () => _selectedStation!,
                initialValue: _selectedStation,
                validator: (value) {
                  if (value == null) {
                    return 'Preencha a estação';
                  }
                  return null;
                },
                internalSetValue: (state, value) {
                  state.didChange(value);
                  setState(() {
                    _selectedStation = value;
                  });
                },
                builder: (state) {
                  return DropdownButtonFormField<Station>(
                    initialValue: state.value,
                    decoration: InputDecoration(
                      labelText: 'Estação',
                      errorText: state.errorText,
                    ),
                    items: stations
                        .map(
                          (station) => DropdownMenuItem<Station>(
                            value: station,
                            child: Text(station.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      state.didChange(value);
                      setState(() {
                        _selectedStation = value;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              TestableFormField<IncidentType>(
                key: const Key('incident-type-selection-field'),
                getValue: () => _selectedIncidentType!,
                initialValue: _selectedIncidentType,
                validator: (value) {
                  if (value == null) {
                    return 'Preencha o tipo de incidente';
                  }
                  return null;
                },
                internalSetValue: (state, value) {
                  state.didChange(value);
                  setState(() {
                    _selectedIncidentType = value;
                  });
                },
                builder: (state) {
                  return DropdownButtonFormField<IncidentType>(
                    initialValue: state.value,
                    decoration: InputDecoration(
                      labelText: 'Tipo de incidente',
                      errorText: state.errorText,
                    ),
                    items: IncidentType.values
                        .map(
                          (incidentType) => DropdownMenuItem<IncidentType>(
                            value: incidentType,
                            child: Text(incidentType.displayName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      state.didChange(value);
                      setState(() {
                        _selectedIncidentType = value;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              TestableFormField<int>(
                key: const Key('incident-rating-field'),
                getValue: () => _rating!,
                initialValue: _rating,
                validator: (value) {
                  if (value == null) {
                    return 'Preencha a avaliação';
                  }
                  if (value < 1 || value > 5) {
                    return 'A avaliação deve ser um inteiro entre 1 e 5';
                  }
                  return null;
                },
                internalSetValue: (state, value) {
                  state.didChange(value);
                  setState(() {
                    _rating = value;
                  });
                },
                builder: (state) {
                  return TextFormField(
                    initialValue: state.value?.toString(),
                    decoration: InputDecoration(
                      labelText: 'Avaliação (1 a 5)',
                      errorText: state.errorText,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (text) {
                      final parsed = int.tryParse(text);
                      state.didChange(parsed);
                      setState(() {
                        _rating = parsed;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              TestableFormField<DateTime>(
                key: const Key('incident-datetime-field'),
                getValue: () => _dateTime!,
                initialValue: _dateTime,
                validator: (value) {
                  if (value == null) {
                    return 'Preencha a data e hora';
                  }
                  return null;
                },
                internalSetValue: (state, value) {
                  state.didChange(value);
                  setState(() {
                    _dateTime = value;
                  });
                },
                builder: (state) {
                  final displayText = state.value == null
                      ? 'Selecionar data e hora'
                      : _dateFormat.format(state.value!);

                  return InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Data e hora',
                      errorText: state.errorText,
                      border: const OutlineInputBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(displayText)),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () async {
                                await _pickDateTime(state);
                              },
                              child: const Text('Escolher'),
                            ),
                            TextButton(
                              onPressed: () {
                                final now = DateTime.now();
                                state.didChange(now);
                                setState(() {
                                  _dateTime = now;
                                });
                              },
                              child: const Text('Agora'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              TestableFormField<String>(
                key: const Key('incident-notes-field'),
                getValue: () => _notes,
                initialValue: _notes,
                internalSetValue: (state, value) {
                  state.didChange(value);
                  setState(() {
                    _notes = value;
                  });
                },
                builder: (state) {
                  return TextFormField(
                    initialValue: state.value,
                    decoration: InputDecoration(
                      labelText: 'Notas (opcional)',
                      errorText: state.errorText,
                    ),
                    maxLines: 3,
                    onChanged: (value) {
                      state.didChange(value);
                      setState(() {
                        _notes = value;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                key: const Key('incident-form-submit-button'),
                onPressed: () async {
                  final isValid = _formKey.currentState?.validate() ?? false;

                  if (!isValid) {
                    return;
                  }

                  final report = IncidentReport(
                    timestamp: _dateTime!,
                    rate: _rating!,
                    type: _selectedIncidentType!,
                    notes: _notes.trim().isEmpty ? null : _notes.trim(),
                  );

                  repository.attachIncident(_selectedStation!.id, report);

                  try {
                    final localDataSource = context.read<SqfliteMetroDataSource>();
                    await localDataSource.attachIncident(_selectedStation!.id, report);
                  } catch (_) {
                    // The app can run without a local datasource configured.
                  }

                  if (!context.mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Incidente registado com sucesso')),
                  );
                },
                child: const Text('Submeter incidente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
