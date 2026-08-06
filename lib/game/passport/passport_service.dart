import 'passport_engine.dart';
import 'passport_license_loader.dart';
import 'passport_stamp_loader.dart';

class PassportService {
  PassportService._();

  static Future<PassportEngine> createEngine() async {
    final stamps =
        await PassportStampLoader.loadStamps();

    final licenses =
        await PassportLicenseLoader.loadLicenses();

    return PassportEngine(
      stamps: stamps,
      licenses: licenses,
    );
  }
}