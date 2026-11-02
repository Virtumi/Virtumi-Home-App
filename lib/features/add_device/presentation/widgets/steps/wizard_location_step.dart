import 'package:flutter/material.dart';

import '../../../../../core/theme/theme.dart';
import '../../../../../shared/models/models.dart';
import '../../../../devices/presentation/widgets/settings_forms/device_location_form.dart';
import '../../../application/new_device_wizard_controller.dart';
import '../../../application/new_device_wizard_state.dart';

class WizardLocationStep extends StatelessWidget {
  const WizardLocationStep({
    super.key,
    required this.state,
    required this.controller,
  });

  final NewDeviceWizardState state;
  final NewDeviceWizardController controller;

  @override
  Widget build(BuildContext context) {
    final location = state.deviceLocation;
    if (location == null) return const SizedBox.shrink();

    return DeviceLocationForm(
      location: location,
      lockDeviceName: isEmsTypeName(state.selectedDevice?.devicetype),
      enabled: true,
      onChanged: controller.updateDeviceLocation,
      footer: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg),
        child: FilledButton(
          onPressed:
              state.isBusy ? null : controller.saveLocationAndContinue,
          child: const Text('Weiter'),
        ),
      ),
    );
  }
}
