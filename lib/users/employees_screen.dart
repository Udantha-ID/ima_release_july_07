import 'package:flutter/material.dart';
import '../services/api_service.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  late Future<List<dynamic>> future;

  @override
  void initState() {
    super.initState();
    future = ApiService.fetchEmployees();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Employees")),
      body: FutureBuilder<List<dynamic>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final list = snapshot.data ?? [];
          if (list.isEmpty) return const Center(child: Text("No data"));

          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = list[i] as Map<String, dynamic>;

              //Your API keys: id, username, created_at, updated_at
              final username = (e["username"] ?? "").toString();
              final password = (e["password"] ?? "").toString();
              final id = (e["id"] ?? "").toString();
              //final createdAt = (e["created_at"] ?? "").toString();

              return ListTile(
                leading: CircleAvatar(child: Text(id.isEmpty ? "?" : id)),
                title: Text(username.isEmpty ? "No Name" : username),
                subtitle: Text(
                  password.isNotEmpty ? "Password: $password" : "No password",
                ),
              //   trailing: Text(
              //     createdAt.isNotEmpty ? "Created: $createdAt" : "No date",
              // ),
              );
            },
          );
        },
      ),
    );
  }
}
