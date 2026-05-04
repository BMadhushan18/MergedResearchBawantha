import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/prediction_response.dart';
import '../utils/constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import 'package:google_fonts/google_fonts.dart';

class TaskResultCard extends StatefulWidget {
  final TaskPrediction task;
  final int sequence;
  final bool initiallyExpanded;

  const TaskResultCard({
    super.key,
    required this.task,
    required this.sequence,
    this.initiallyExpanded = false,
  });

  @override
  State<TaskResultCard> createState() => _TaskResultCardState();
}

class _TaskResultCardState extends State<TaskResultCard> {
  late bool _expanded;
  final NumberFormat _money = NumberFormat('#,##0', 'en_US');

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _expanded,
          onExpansionChanged: (value) => setState(() => _expanded = value),
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.flameOrange,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${widget.sequence}',
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.taskName,
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    Text(
                      t.boqDescription,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8, left: 44),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Rs. ${_money.format(t.costSummary.taskTotalCostRs)}',
                  style: GoogleFonts.inter(
                    color: AppColors.flameOrange,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.forgeBlackActual.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${t.labour.totalGang} GANG',
                    style: GoogleFonts.inter(
                      color: AppColors.forgeBlackActual,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: [
            const Divider(height: 32),
            _buildVehicleSection(t.vehicle),
            const SizedBox(height: 12),
            _buildMachinerySection(t.machinery),
            const SizedBox(height: 12),
            _buildLabourSection(t.labour),
            const SizedBox(height: 12),
            _buildFuelCostSection(t.fuel, t.costSummary),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleSection(VehicleResult v) {
    return _sectionCard(
      borderColor: AppColors.flameOrange,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(v.vehicleType.toUpperCase(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.flameOrange, letterSpacing: 0.5)),
              ),
              _countBadge(v.vehicleCount, AppColors.flameOrange),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            v.vehiclePurpose,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _metricGrid('Hourly', 'Rs. ${_money.format(v.vehicleHourlyCostRs)}')),
              Expanded(child: _metricGrid('Daily', 'Rs. ${_money.format(v.vehicleDailyRentalRs)}')),
              Expanded(child: _metricGrid('Fuel', '${v.vehicleFuelLph.toStringAsFixed(1)} L/h')),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Total Daily: Rs. ${_money.format(v.vehicleTotalDailyCostRs)}',
              style: GoogleFonts.inter(color: AppColors.flameOrange, fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMachinerySection(MachineryResult m) {
    return _sectionCard(
      borderColor: const Color(0xFF00897B),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(m.machineryType.toUpperCase(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF00897B), letterSpacing: 0.5)),
              ),
              _countBadge(m.machineryCount, const Color(0xFF00897B)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            m.machineryPurpose,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _metricGrid('Hourly', 'Rs. ${_money.format(m.machineryHourlyCostRs)}')),
              Expanded(child: _metricGrid('Daily', 'Rs. ${_money.format(m.machineryDailyRentalRs)}')),
              Expanded(child: _metricGrid('Fuel', '${m.machineryFuelLph.toStringAsFixed(1)} L/h')),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Total Daily: Rs. ${_money.format(m.machineryTotalDailyCostRs)}',
              style: GoogleFonts.inter(color: const Color(0xFF00897B), fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabourSection(LabourGangResult l) {
    return _sectionCard(
      borderColor: AppColors.forgeBlackActual,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _pill('SKILLED: ${l.totalSkilled}', const Color(0xFF1976D2)),
              const SizedBox(width: 8),
              _pill('SEMI-SKILLED: ${l.totalSemiSkilled}', const Color(0xFFF9A825)),
              const SizedBox(width: 8),
              _pill('UNSKILLED: ${l.totalUnskilled}', const Color(0xFF757575)),
            ],
          ),
          const SizedBox(height: 12),
          ...l.activeRoles.entries.map((entry) {
            final role = entry.key;
            final icon = kRoleIcons[role] ?? Icons.person;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: AppColors.forgeBlackActual),
                  const SizedBox(width: 10),
                  Expanded(child: Text(role, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary))),
                  Text('×${entry.value}', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(width: 12),
                  Text(
                    'Rs. ${_money.format(kRoleDailyRates[role] ?? 0)}/day',
                    style: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 12),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Daily Labour: Rs. ${_money.format(l.labourDailyCostRs)}',
              style: GoogleFonts.inter(color: AppColors.forgeBlackActual, fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFuelCostSection(FuelAnalysis f, CostSummary c) {
    return _sectionCard(
      borderColor: AppColors.flameOrange,
      child: ExpansionTile(
        title: Text('FUEL & COST ANALYSIS', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: 0.5)),
        initiallyExpanded: false,
        maintainState: true,
        childrenPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${f.totalFuelLph.toStringAsFixed(1)} L/H TOTAL  ·  ${f.totalFuelPerDayLitres.toStringAsFixed(1)} L/DAY',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textTertiary),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: efficiencyColor(f.efficiencyRating).withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                f.efficiencyRating.toUpperCase(),
                style: GoogleFonts.inter(color: efficiencyColor(f.efficiencyRating), fontWeight: FontWeight.w800, fontSize: 10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _costLine('Vehicle/Machinery', 'Rs. ${_money.format(c.vehicleDailyCostRs + c.machineryDailyCostRs)} / DAY'),
          _costLine('Labour Allocation', 'Rs. ${_money.format(c.labourDailyCostRs)} / DAY'),
          const Divider(height: 24),
          _costLine('Total Daily Logistics', 'Rs. ${_money.format(c.totalDailyCostRs)}'),
          _costLine('Task Duration', '× ${c.workingDays} DAYS'),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'TASK TOTAL: Rs. ${_money.format(c.taskTotalCostRs)}',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.flameOrange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required Color borderColor, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        border: Border.all(color: AppColors.divider, width: 0.5),
        color: AppColors.background,
      ),
      child: child,
    );
  }

  Widget _metricGrid(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
        ),
      ],
    );
  }

  Widget _countBadge(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('×$count', style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }

  Widget _costLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
          Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 13)),
        ],
      ),
    );
  }
}
