import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/config.dart';
import '../core/endpoints.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final api = ApiClient(kDinethApiBase);

  bool loading = false;
  String? message;
  String? error;

  Future<void> _sync(String? dataset) async {
    setState(() {
      loading = true;
      message = null;
      error = null;
    });

    try {
      Map<String, dynamic> res;
      if (dataset == null) {
        res = await api.post(Endpoints.feedbackSyncAll, {});
      } else {
        res = await api.post(Endpoints.feedbackSync(dataset), {});
      }
      // display raw response so user can see counts
      message = res.toString();
    } catch (e) {
      error = e.toString();
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Widget _button(String text, String? dataset) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ElevatedButton(
        onPressed: loading ? null : () => _sync(dataset),
        child: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback Sync')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Trigger manual synchronization of the feedback spreadsheets.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            _button('Sync all datasets', null),
            _button('Sync paint form', 'paint'),
            _button('Sync skimcoat form', 'skimcoat'),
            _button('Sync wood form', 'wood'),
            const SizedBox(height: 24),
            if (loading) const Center(child: CircularProgressIndicator()),
            if (message != null)
              Text(
                message!,
                style: const TextStyle(color: Colors.green),
              ),
            if (error != null)
              Text(
                error!,
                style: const TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }
}
