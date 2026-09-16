enum GenericOperationType {
  getNames // exemplo
}

/// Classe generica para operacoes que nao estejam nas outras DataSources.
///
/// Exemplo de uso:
///
/// class MyGenericDataSource extends GenericDataSource {
///   final List<String> names = ["John", "Doe"];
///
///   @override
///   Future<dynamic> execute({required GenericOperationType type, dynamic data}) async {
///     switch (type) {
///       case GenericOperationType.getNames:
///         return names;
///     }
///   }
/// }
abstract class GenericDataSource {
  Future<dynamic> execute({required GenericOperationType type, dynamic data});
}
