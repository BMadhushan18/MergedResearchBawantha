import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/project/project_model.dart';
import '../models/project/material_model.dart';
import '../models/project/supplier_model.dart';
import '../models/project/vehicle_model.dart';
import '../models/project/worker_model.dart';
import '../models/project/equipment_model.dart';
import '../models/project/price_model.dart';
import '../models/project/boq_model.dart';
import '../models/project/purchasing_model.dart';
import '../models/project/stock_model.dart';
import '../models/project/transport_model.dart';
import '../models/project/labour_ops_model.dart';
import '../models/project/progress_model.dart';
import '../models/project/qc_model.dart';
import '../models/project/safety_model.dart';
import '../models/project/audit_model.dart';
import '../services/mongo_api_service.dart';
import '../models/phase_duration_model.dart';

class ProjectProvider extends ChangeNotifier {
  final MongoApiService _api = MongoApiService();
  final _uuid = const Uuid();

  // ─── State ─────────────────────────────────────────────────────────────────
  ProjectModel? _currentProject;
  ProjectModel? get currentProject => _currentProject;
  bool _loading = false;
  bool get loading => _loading;
  String? _error;
  String? get error => _error;

  // ─── Lists (same names as ProjectProvider) ─────────────────────────────────
  List<ProjectModel> projects = [];
  List<MaterialModel> materials = [];
  List<HardwareStore> hardwareStores = [];
  List<SupplierModel> suppliers = [];
  List<VehicleModel> vehicles = [];
  List<WorkerModel> workers = [];
  List<EquipmentModel> equipment = [];
  List<ToolModel> tools = [];
  List<PriceRecord> priceRecords = [];
  List<BOQItem> boqItems = [];
  List<PurchaseRequisition> prs = [];
  List<PurchaseOrder> pos = [];
  List<GRN> grns = [];
  List<SupplierInvoice> invoices = [];
  List<PaymentRecord> payments = [];
  List<StockEntry> stockLedger = [];
  List<IssueNote> issueNotes = [];
  List<StockAdjustment> stockAdjustments = [];
  List<MinStockAlert> stockAlerts = [];
  List<TripModel> trips = [];
  List<DailyAttendance> attendance = [];
  List<WorkAllocation> workAllocations = [];
  List<ProgressUpdate> progressUpdates = [];
  List<IPC> ipcs = [];
  List<QCChecklist> qcChecklists = [];
  List<NCReport> ncrs = [];
  List<ToolboxMeeting> toolboxMeetings = [];
  List<Permit> permits = [];
  List<Incident> incidents = [];
  List<AuditLog> auditLog = [];
  List<PhaseDurationModel> phaseDurations = [];

  // ─── Measurements version ──────────────────────────────────────────────────
  // Incremented whenever the user edits a measurement in the Overview tab
  // and the change is successfully persisted to the DB.
  // The BOQ tab watches this value and auto-refetches when it changes.
  int _measurementsVersion = 0;
  int get measurementsVersion => _measurementsVersion;

  void markMeasurementsChanged() {
    _measurementsVersion++;
    notifyListeners();
  }

  // ─── ThreeJS state ─────────────────────────────────────────────────────────
  String? _threejsFoundation;
  String? _threejsFinishing;
  bool _threejsLoading = false;

  String? get threejsFoundation => _threejsFoundation;
  String? get threejsFinishing => _threejsFinishing;
  bool get threejsLoading => _threejsLoading;

  Future<String?> fetchThreeJsCategory(String category) async {
    if (_currentProject == null) return null;
    _threejsLoading = true;
    notifyListeners();
    try {
      final html = await _api.getThreeJsCategory(_currentProject!.projectId, category);
      if (category == 'foundation') _threejsFoundation = html;
      if (category == 'finishing') _threejsFinishing = html;
      return html;
    } catch (e) {
      debugPrint('fetchThreeJsCategory error: $e');
      return null;
    } finally {
      _threejsLoading = false;
      notifyListeners();
    }
  }

  void clearThreeJsCache() {
    _threejsFoundation = null;
    _threejsFinishing = null;
    notifyListeners();
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  void _setToken(String token) => _api.saveToken(token);

  void setToken(String token) {
    _api.saveToken(token);
  }

  Future<void> loadApiToken() => _api.loadToken();

  // ─── Load projects list ────────────────────────────────────────────────────
  Future<void> listenProjects() async {
    try {
      await _api.loadToken();
      final raw = await _api.getProjects();
      projects = raw
          .map((d) => ProjectModel.fromMap(
              d['projectId'] ?? d['_id'] ?? '',
              Map<String, dynamic>.from(d)))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('ProjectProvider.listenProjects error: $e');
    }
  }

  // Ensure current project context exists (without loading all subcollections).
  Future<void> ensureCurrentProject(String projectId) async {
    if ((_currentProject?.projectId ?? '') == projectId) return;

    try {
      await _api.loadToken();
      final raw = await _api.getProject(projectId);
      _currentProject = ProjectModel.fromMap(
        raw['projectId'] ?? raw['_id'] ?? projectId,
        Map<String, dynamic>.from(raw),
      );
      notifyListeners();
      return;
    } catch (_) {
      // Fallback to already loaded project list if direct fetch fails.
      final idx = projects.indexWhere((p) => p.projectId == projectId);
      if (idx >= 0) {
        _currentProject = projects[idx];
        notifyListeners();
      }
    }
  }

  // ─── Select project + load all subcollections ──────────────────────────────
  Future<void> selectProject(String projectId) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await _api.loadToken();
      // Load project
      final raw = await _api.getProject(projectId);
      _currentProject = ProjectModel.fromMap(
          raw['projectId'] ?? raw['_id'] ?? projectId,
          Map<String, dynamic>.from(raw));

      // Load all subcollections in parallel
      final futures = await Future.wait([
        _loadSub(projectId, 'materials'),           // 0
        _loadSub(projectId, 'hardware_stores'),      // 1
        _loadSub(projectId, 'suppliers'),            // 2
        _loadSub(projectId, 'vehicles'),             // 3
        _loadSub(projectId, 'workers'),              // 4
        _loadSub(projectId, 'equipment'),            // 5
        _loadSub(projectId, 'tools'),                // 6
        _loadSub(projectId, 'price_records'),        // 7
        _loadSub(projectId, 'boq'),                  // 8
        _loadSub(projectId, 'purchase_requisitions'),// 9
        _loadSub(projectId, 'purchase_orders'),      // 10
        _loadSub(projectId, 'grns'),                 // 11
        _loadSub(projectId, 'invoices'),             // 12
        _loadSub(projectId, 'payments'),             // 13
        _loadSub(projectId, 'stock'),                // 14
        _loadSub(projectId, 'issue_notes'),          // 15
        _loadSub(projectId, 'stock_adjustments'),    // 16
        _loadSub(projectId, 'stock_alerts'),         // 17
        _loadSub(projectId, 'trips'),                // 18
        _loadSub(projectId, 'attendance'),           // 19
        _loadSub(projectId, 'work_allocations'),     // 20
        _loadSub(projectId, 'progress'),             // 21
        _loadSub(projectId, 'ipcs'),                 // 22
        _loadSub(projectId, 'qc_checklists'),        // 23
        _loadSub(projectId, 'ncrs'),                 // 24
        _loadSub(projectId, 'incidents'),            // 25
        _loadSub(projectId, 'toolbox_meetings'),     // 26
        _loadSub(projectId, 'permits'),              // 27
        _loadSub(projectId, 'audit_logs'),           // 28
        _api.getPhaseDurations(projectId),           

      ]);

      materials         = _parse(futures[0],  (d) => MaterialModel.fromMap(d));
      hardwareStores    = _parse(futures[1],  (d) => HardwareStore.fromMap(d));
      suppliers         = _parse(futures[2],  (d) => SupplierModel.fromMap(d));
      vehicles          = _parse(futures[3],  (d) => VehicleModel.fromMap(d));
      workers           = _parse(futures[4],  (d) => WorkerModel.fromMap(d));
      equipment         = _parse(futures[5],  (d) => EquipmentModel.fromMap(d));
      tools             = _parse(futures[6],  (d) => ToolModel.fromMap(d));
      priceRecords      = _parse(futures[7],  (d) => PriceRecord.fromMap(d));
      boqItems          = _parse(futures[8],  (d) => BOQItem.fromMap(d));
      prs               = _parse(futures[9],  (d) => PurchaseRequisition.fromMap(d));
      pos               = _parse(futures[10], (d) => PurchaseOrder.fromMap(d));
      grns              = _parse(futures[11], (d) => GRN.fromMap(d));
      invoices          = _parse(futures[12], (d) => SupplierInvoice.fromMap(d));
      payments          = _parse(futures[13], (d) => PaymentRecord.fromMap(d));
      stockLedger       = _parse(futures[14], (d) => StockEntry.fromMap(d));
      issueNotes        = _parse(futures[15], (d) => IssueNote.fromMap(d));
      stockAdjustments  = _parse(futures[16], (d) => StockAdjustment.fromMap(d));
      stockAlerts       = _parse(futures[17], (d) => MinStockAlert.fromMap(d));
      trips             = _parse(futures[18], (d) => TripModel.fromMap(d));
      attendance        = _parse(futures[19], (d) => DailyAttendance.fromMap(d));
      workAllocations   = _parse(futures[20], (d) => WorkAllocation.fromMap(d));
      progressUpdates   = _parse(futures[21], (d) => ProgressUpdate.fromMap(d));
      ipcs              = _parse(futures[22], (d) => IPC.fromMap(d));
      qcChecklists      = _parse(futures[23], (d) => QCChecklist.fromMap(d));
      ncrs              = _parse(futures[24], (d) => NCReport.fromMap(d));
      incidents         = _parse(futures[25], (d) => Incident.fromMap(d));
      toolboxMeetings   = _parse(futures[26], (d) => ToolboxMeeting.fromMap(d));
      permits           = _parse(futures[27], (d) => Permit.fromMap(d));
      auditLog          = _parse(futures[28], (d) => AuditLog.fromMap(d));

      // parse phase durations list
      final rawPhases = (futures[29] as List<dynamic>);
      phaseDurations = rawPhases
          .map((e) => PhaseDurationModel.fromMap(Map<String, dynamic>.from(e)))
          .toList();

      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
    }
  }

  // reload phase durations only (useful when PhaseWise screen opens)
  Future<void> refreshPhaseDurations() async {
    final pid = _currentProject?.projectId;
    if (pid == null || pid.isEmpty) return;

    try {
      await _api.loadToken();
      final raw = await _api.getPhaseDurations(pid);
      phaseDurations = raw
          .map((e) => PhaseDurationModel.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('ProjectProvider.refreshPhaseDurations error: $e');
    }
  }

  // save (upsert) one phase duration to backend + update local list
  Future<void> savePhaseDuration({
    required String phaseId,
    required String phaseName,
    required int durationDays,
    required int laborCount,
  }) async {
    final pid = _currentProject?.projectId;
    if (pid == null || pid.isEmpty) {
      throw Exception('No project selected (pid is null)');
    }

    await _api.loadToken();

    final payload = {
      'pid': pid,
      'phaseId': phaseId,
      'phaseName': phaseName,
      'durationDays': durationDays,
      'laborCount': laborCount,
    };

    await _api.loadToken();
    await _api.savePhaseDuration(
      pid: pid,
      phaseId: phaseId,
      phaseName: phaseName,
      durationDays: durationDays,
      laborCount: laborCount,
    );

    // Update local cache (upsert by phaseId)
    final idx = phaseDurations.indexWhere((p) => p.phaseId == phaseId);
    final updated = PhaseDurationModel(
      pid: pid,
      phaseId: phaseId,
      phaseName: phaseName,
      durationDays: durationDays,
      laborCount: laborCount,
    );

    if (idx >= 0) {
      phaseDurations[idx] = updated;
    } else {
      phaseDurations.add(updated);
    }

    notifyListeners();
  }

  // ─── Delete project ──────────────────────────────────────────────────────
  Future<void> deleteProject(String projectId) async {
    await _api.loadToken();
    await _api.deleteProject(projectId);
    if (_currentProject?.projectId == projectId) {
      clearProject();
    } else {
      projects.removeWhere((p) => p.projectId == projectId);
      notifyListeners();
    }
  }

  void clearProject() {
    _currentProject = null;
    materials = []; hardwareStores = []; suppliers = [];
    vehicles = []; workers = []; equipment = []; tools = [];
    priceRecords = []; boqItems = [];
    prs = []; pos = []; grns = []; invoices = []; payments = [];
    stockLedger = []; issueNotes = []; stockAdjustments = []; stockAlerts = [];
    trips = []; attendance = []; workAllocations = [];
    progressUpdates = []; ipcs = [];
    qcChecklists = []; ncrs = [];
    toolboxMeetings = []; permits = []; incidents = []; auditLog = [];

    // phase
    phaseDurations = [];

    notifyListeners();
  }

  // ─── Generic sub-doc loader ────────────────────────────────────────────────
  Future<List<dynamic>> _loadSub(String pid, String sub) async {
    try {
      return await _api.getSub(pid, sub);
    } catch (_) {
      return [];
    }
  }

  List<T> _parse<T>(List<dynamic> raw, T Function(Map<String, dynamic>) fromMap) {
    return raw
        .map((d) {
          try {
            return fromMap(Map<String, dynamic>.from(d));
          } catch (_) {
            return null;
          }
        })
        .whereType<T>()
        .toList();
  }

  // ─── Generic add helper ────────────────────────────────────────────────────
  Future<String> _addSub(String sub, Map<String, dynamic> data) async {
    final pid = _currentProject!.projectId;
    await _api.addSub(pid, sub, data);
    return data.values.first as String? ?? '';
  }

  // ─── Create project ────────────────────────────────────────────────────────
  Future<String> createProject(ProjectModel project) async {
    await _api.createProject(project.toMap());
    await listenProjects();
    await selectProject(project.projectId);
    return project.projectId;
  }

  Future<void> updateProject(ProjectModel project) async {
    await _api.updateProject(project.projectId, project.toMap());
    await listenProjects();
  }

  // ─── Materials ─────────────────────────────────────────────────────────────
  Future<void> addMaterial(MaterialModel m) async {
    final id = _uuid.v4();
    final data = {...m.toMap(), 'materialId': id};
    await _api.addSub(_currentProject!.projectId, 'materials', data);
    materials.add(MaterialModel.fromMap(Map<String, dynamic>.from(data)));
    notifyListeners();
  }

  // ─── Suppliers ─────────────────────────────────────────────────────────────
  Future<void> addSupplier(SupplierModel s) async {
    final id = _uuid.v4();
    final data = {...s.toMap(), 'supplierId': id};
    await _api.addSub(_currentProject!.projectId, 'suppliers', data);
    suppliers.add(SupplierModel.fromMap(Map<String, dynamic>.from(data)));
    notifyListeners();
  }

  // ─── Workers ──────────────────────────────────────────────────────────────
  Future<void> addWorker(WorkerModel w) async {
    final data = {...w.toMap(), 'workerId': w.workerId};
    await _api.addSub(_currentProject!.projectId, 'workers', data);
    workers.add(WorkerModel.fromMap(Map<String, dynamic>.from(data)));
    notifyListeners();
  }

  // ─── Vehicles ─────────────────────────────────────────────────────────────
  Future<void> addVehicle(VehicleModel v) async {
    final id = _uuid.v4();
    final data = {...v.toMap(), 'vehicleId': id};
    await _api.addSub(_currentProject!.projectId, 'vehicles', data);
    vehicles.add(VehicleModel.fromMap(Map<String, dynamic>.from(data)));
    notifyListeners();
  }

  // ─── BOQ ──────────────────────────────────────────────────────────────────
  Future<void> addBOQItem(BOQItem item) async {
    final id = _uuid.v4();
    final data = {...item.toMap(), 'boqItemId': id};
    await _api.addSub(_currentProject!.projectId, 'boq', data);
    boqItems.add(BOQItem.fromMap(Map<String, dynamic>.from(data)));
    notifyListeners();
  }

  Future<void> updateBOQItem(BOQItem item) async {
    await _api.updateSub(
        _currentProject!.projectId, 'boq', item.boqItemId, item.toMap());
    final idx = boqItems.indexWhere((b) => b.boqItemId == item.boqItemId);
    if (idx >= 0) boqItems[idx] = item;
    notifyListeners();
  }

  // ─── Price Records ─────────────────────────────────────────────────────────
  Future<void> addPriceRecord(PriceRecord p) async {
    final id = _uuid.v4();
    final data = {...p.toMap(), 'priceRecordId': id};
    await _api.addSub(_currentProject!.projectId, 'price_records', data);
    priceRecords.add(PriceRecord.fromMap(Map<String, dynamic>.from(data)));
    notifyListeners();
  }

  // ─── Purchase Requisitions ─────────────────────────────────────────────────
  Future<void> addPR(PurchaseRequisition pr) async {
    final id = _uuid.v4();
    final data = {...pr.toMap(), 'prId': id};
    await _api.addSub(_currentProject!.projectId, 'purchase_requisitions', data);
    prs.add(PurchaseRequisition.fromMap(Map<String, dynamic>.from(data)));
    notifyListeners();
  }

  // ─── Purchase Orders ──────────────────────────────────────────────────────
  Future<void> addPO(PurchaseOrder po) async {
    final id = _uuid.v4();
    final data = {...po.toMap(), 'poId': id};
    await _api.addSub(_currentProject!.projectId, 'purchase_orders', data);
    pos.add(PurchaseOrder.fromMap(Map<String, dynamic>.from(data)));
    notifyListeners();
  }

  // ─── GRNs ─────────────────────────────────────────────────────────────────
  Future<void> addGRN(GRN grn) async {
    final id = _uuid.v4();
    final data = {...grn.toMap(), 'grnId': id};
    await _api.addSub(_currentProject!.projectId, 'grns', data);
    grns.add(GRN.fromMap(Map<String, dynamic>.from(data)));
    notifyListeners();
  }

  // ─── Stock ────────────────────────────────────────────────────────────────
  Future<void> addStockEntry(StockEntry entry) async {
    final id = _uuid.v4();
    final data = {...entry.toMap(), 'entryId': id};
    await _api.addSub(_currentProject!.projectId, 'stock', data);
    stockLedger.add(StockEntry.fromMap(Map<String, dynamic>.from(data)));
    notifyListeners();
  }

  // ─── Trips ────────────────────────────────────────────────────────────────
  Future<void> addTrip(TripModel trip) async {
    final id = _uuid.v4();
    final data = {...trip.toMap(), 'tripId': id};
    await _api.addSub(_currentProject!.projectId, 'trips', data);
    trips.add(TripModel.fromMap(Map<String, dynamic>.from(data)));
    notifyListeners();
  }

  // ─── Attendance ───────────────────────────────────────────────────────────
  Future<void> saveAttendance(DailyAttendance att) async {
    final data = att.toMap();
    await _api.addSub(_currentProject!.projectId, 'attendance', data);
    attendance.add(att);
    notifyListeners();
  }

  // ─── Progress ─────────────────────────────────────────────────────────────
  Future<void> addProgressUpdate(ProgressUpdate p) async {
    final id = _uuid.v4();
    final data = {...p.toMap(), 'progressId': id};
    await _api.addSub(_currentProject!.projectId, 'progress', data);
    progressUpdates.add(ProgressUpdate.fromMap(Map<String, dynamic>.from(data)));
    notifyListeners();
  }

  // ─── Safety ───────────────────────────────────────────────────────────────
  Future<void> addIncident(Incident inc) async {
    final id = _uuid.v4();
    final data = {...inc.toMap(), 'incidentId': id};
    await _api.addSub(_currentProject!.projectId, 'incidents', data);
    incidents.add(Incident.fromMap(Map<String, dynamic>.from(data)));
    notifyListeners();
  }

  Future<void> addToolboxMeeting(ToolboxMeeting tbm) async {
    final id = _uuid.v4();
    final data = {...tbm.toMap(), 'meetingId': id};
    await _api.addSub(_currentProject!.projectId, 'toolbox_meetings', data);
    toolboxMeetings.add(ToolboxMeeting.fromMap(Map<String, dynamic>.from(data)));
    notifyListeners();
  }

  // ─── Hardware Stores ──────────────────────────────────────────────────────
  Future<void> addHardwareStore(HardwareStore hs) async {
    final id = _uuid.v4();
    final data = {...hs.toMap(), 'storeId': id};
    await _api.addSub(_currentProject!.projectId, 'hardware_stores', data);
    hardwareStores.add(HardwareStore.fromMap(Map<String, dynamic>.from(data)));
    notifyListeners();
  }

  // ─── Equipment & Tools ────────────────────────────────────────────────────
  Future<void> addEquipment(EquipmentModel eq) async {
    final id = _uuid.v4();
    final data = {...eq.toMap(), 'equipmentId': id};
    await _api.addSub(_currentProject!.projectId, 'equipment', data);
    equipment.add(EquipmentModel.fromMap(Map<String, dynamic>.from(data)));
    notifyListeners();
  }

  Future<void> addTool(ToolModel tool) async {
    final id = _uuid.v4();
    final data = {...tool.toMap(), 'toolId': id};
    await _api.addSub(_currentProject!.projectId, 'tools', data);
    tools.add(ToolModel.fromMap(Map<String, dynamic>.from(data)));
    notifyListeners();
  }

  // ─── Issue Notes ──────────────────────────────────────────────────────────
  Future<void> addIssueNote(IssueNote note) async {
    final id = _uuid.v4();
    final data = {...note.toMap(), 'issueNoteId': id};
    await _api.addSub(_currentProject!.projectId, 'issue_notes', data);
    issueNotes.add(IssueNote.fromMap(Map<String, dynamic>.from(data)));
    notifyListeners();
  }

  // ─── Stock Adjustments ────────────────────────────────────────────────────
  Future<void> addStockAdjustment(StockAdjustment adj) async {
    final id = _uuid.v4();
    final data = {...adj.toMap(), 'adjustmentId': id};
    await _api.addSub(_currentProject!.projectId, 'stock_adjustments', data);
    stockAdjustments.add(StockAdjustment.fromMap(Map<String, dynamic>.from(data)));
    notifyListeners();
  }

  Future<void> addStockAlert(MinStockAlert alert) async {
    final data = alert.toMap();
    await _api.addSub(_currentProject!.projectId, 'stock_alerts', data);
    stockAlerts.add(alert);
    notifyListeners();
  }

  // ─── Work Allocation ──────────────────────────────────────────────────────
  Future<void> addWorkAllocation(WorkAllocation wa) async {
    final id = _uuid.v4();
    final data = {...wa.toMap(), 'allocationId': id};
    await _api.addSub(_currentProject!.projectId, 'work_allocations', data);
    workAllocations.add(WorkAllocation.fromMap(Map<String, dynamic>.from(data)));
    notifyListeners();
  }

  // ─── IPC ──────────────────────────────────────────────────────────────────
  Future<void> addIPC(IPC ipc) async {
    final id = _uuid.v4();
    final data = {...ipc.toMap(), 'ipcId': id};
    await _api.addSub(_currentProject!.projectId, 'ipcs', data);
    ipcs.add(IPC.fromMap(Map<String, dynamic>.from(data)));
    notifyListeners();
  }

  // ─── QC ───────────────────────────────────────────────────────────────────
  Future<void> addQCChecklist(QCChecklist cl) async {
    final id = _uuid.v4();
    final data = {...cl.toMap(), 'checklistId': id};
    await _api.addSub(_currentProject!.projectId, 'qc_checklists', data);
    qcChecklists.add(QCChecklist.fromMap(Map<String, dynamic>.from(data)));
    notifyListeners();
  }

  Future<void> addNCR(NCReport ncr) async {
    final id = _uuid.v4();
    final data = {...ncr.toMap(), 'ncrId': id};
    await _api.addSub(_currentProject!.projectId, 'ncrs', data);
    ncrs.add(NCReport.fromMap(Map<String, dynamic>.from(data)));
    notifyListeners();
  }

  // ─── Permits ──────────────────────────────────────────────────────────────
  Future<void> addPermit(Permit permit) async {
    final id = _uuid.v4();
    final data = {...permit.toMap(), 'permitId': id};
    await _api.addSub(_currentProject!.projectId, 'permits', data);
    permits.add(Permit.fromMap(Map<String, dynamic>.from(data)));
    notifyListeners();
  }

  // ─── Supplier Invoices ────────────────────────────────────────────────────
  Future<void> addSupplierInvoice(SupplierInvoice inv) async {
    final id = _uuid.v4();
    final data = {...inv.toMap(), 'invoiceId': id};
    await _api.addSub(_currentProject!.projectId, 'invoices', data);
    invoices.add(SupplierInvoice.fromMap(Map<String, dynamic>.from(data)));
    notifyListeners();
  }

  // ─── Payments ─────────────────────────────────────────────────────────────
  Future<void> addPayment(PaymentRecord payment) async {
    final id = _uuid.v4();
    final data = {...payment.toMap(), 'paymentId': id};
    await _api.addSub(_currentProject!.projectId, 'payments', data);
    payments.add(PaymentRecord.fromMap(Map<String, dynamic>.from(data)));
    notifyListeners();
  }

  // ─── Audit ────────────────────────────────────────────────────────────────
  Future<void> logAudit(AuditLog log) async {
    final id = _uuid.v4();
    final data = {...log.toMap(), 'logId': id};
    await _api.addSub(_currentProject!.projectId, 'audit_logs', data);
    auditLog.add(AuditLog.fromMap(Map<String, dynamic>.from(data)));
    notifyListeners();
  }
}

/// Backward-compatible alias for older screens.
typedef MongoProjectProvider = ProjectProvider;
