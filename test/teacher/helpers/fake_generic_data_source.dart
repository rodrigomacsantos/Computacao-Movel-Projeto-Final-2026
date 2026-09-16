import 'package:cmproject/data/generic_data_source.dart';

class FakeGenericDataSource extends GenericDataSource {

  @override
  Future execute({required GenericOperationType type, data}) async {
    return null;
  }

}