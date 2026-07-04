import 'package:car_luxe_cleaning_flutter/shared/models/client.dart';

abstract class ClientRepository {
  Future<List<Client>> searchClients(String query);
}
