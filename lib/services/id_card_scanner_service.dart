import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import '../repositories/student_directory.dart';

/// Holds all extracted details from the two ID card images
class ExtractedIdData {
  String name;
  String rollNo;
  String course;
  String department;
  String college;
  String collegeAffiliation;
  String validity;
  String address;
  String pincode;
  String email;
  List<String> phones;
  String dob;
  String bloodGroup;
  String avatarBase64;
  String? avatarFilePath;

  ExtractedIdData({
    this.name = '',
    this.rollNo = '',
    this.course = 'B.Tech.',
    this.department = 'Information Technology',
    this.college = 'K.L.N. COLLEGE OF ENGINEERING',
    this.collegeAffiliation = 'An Autonomous Institution, Affiliated to Anna University, Chennai (Accredited by NAAC)',
    this.validity = 'August 2023 to May 2027',
    this.address = '',
    this.pincode = '',
    this.email = '',
    List<String>? phones,
    this.dob = '',
    this.bloodGroup = '',
    this.avatarBase64 = '',
    this.avatarFilePath,
  }) : phones = phones ?? [];
}

class IdCardScannerService {
  static final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  static const List<String> _blacklistWords = [
    'STUDENT', 'STUDET', 'STUDNT', 'PHOTO', 'CARD', 'SIGNATURE',
    'COLLEGE', 'ENGINEERING', 'AUTONOMOUS', 'ANNA UNIVERSITY', 'NAAC',
    'POTTAPALAYAM', 'MADURAI', 'CHENNAI', 'PHONE', 'VALIDITY', 'VALID',
    'KLNCE', 'WWW.', 'BATCH', 'PRINCIPAL', 'HOLDER', 'IDENTITY', 'BARCODE',
    'AFFILIATED', 'ACCREDITED', 'INSTITUTION', 'RNGIS', 'OP RNGIS', 'OP',
    'WEBSITE', 'AN AUTONOMOUS', 'CONVENER', 'COMMITTEE', 'RAGGING',
  ];

  /// Process both Front and Back images and extract structured data + student photo
  static Future<ExtractedIdData> processIdCards({
    required String frontImagePath,
    required String backImagePath,
  }) async {
    final result = ExtractedIdData();
    Rect? nameBox;
    Rect? courseBox;

    // 1. Perform OCR on Front Image
    try {
      final frontInputImage = InputImage.fromFilePath(frontImagePath);
      final frontRecognized = await _textRecognizer.processImage(frontInputImage);
      
      // Collect and sort all recognized lines by physical vertical position (top-to-bottom)
      final frontLines = <TextLine>[];
      for (final block in frontRecognized.blocks) {
        frontLines.addAll(block.lines);
      }
      frontLines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

      final boxes = _parseFrontLines(frontLines, frontRecognized.text, result);
      nameBox = boxes['name'];
      courseBox = boxes['course'];
    } catch (e) {
      debugPrint('OCR front error: $e');
    }

    // 2. Extract Student Portrait from Front Image anchored to detected name/course position
    try {
      final photoData = await extractStudentPhoto(
        frontImagePath,
        nameBox: nameBox,
        courseBox: courseBox,
      );
      result.avatarBase64 = photoData['base64'] ?? '';
      result.avatarFilePath = photoData['path'];
    } catch (e) {
      debugPrint('Error extracting student photo: $e');
    }

    // 3. Perform OCR on Back Image
    try {
      final backInputImage = InputImage.fromFilePath(backImagePath);
      final backRecognized = await _textRecognizer.processImage(backInputImage);

      final backLines = <TextLine>[];
      for (final block in backRecognized.blocks) {
        backLines.addAll(block.lines);
      }
      backLines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

      _parseBackLines(backLines, backRecognized.text, result);
    } catch (e) {
      debugPrint('OCR back error: $e');
    }

    // 4. Enrich from verified directory ONLY if roll number matches a known entry
    _enrichFromKnownDirectory(result);

    return result;
  }

  /// Automatically crop student portrait from Front ID card
  /// Uses the detected name/course bounding box as an exact physical anchor
  static Future<Map<String, String>> extractStudentPhoto(
    String imagePath, {
    Rect? nameBox,
    Rect? courseBox,
  }) async {
    final file = File(imagePath);
    if (!file.existsSync()) return {};

    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return {};

    int cropX;
    int cropY;
    int cropW;
    int cropH;

    // Determine bottom of the photo box
    // Photo box sits cleanly 5-15px above the student's name line
    double? anchorBottomY;
    if (nameBox != null && nameBox.top > (image.height * 0.20)) {
      anchorBottomY = nameBox.top - 8;
    } else if (courseBox != null && courseBox.top > (image.height * 0.25)) {
      anchorBottomY = courseBox.top - 35;
    }

    if (anchorBottomY != null && anchorBottomY > (image.height * 0.25)) {
      // Anchored Crop:
      // The photo width is ~33% of image width, centered on the left half of the card
      cropW = (image.width * 0.33).toInt().clamp(60, image.width);
      cropH = (cropW * 1.25).toInt().clamp(60, image.height);
      cropX = (image.width * 0.23).toInt().clamp(0, image.width - cropW);
      cropY = (anchorBottomY - cropH).toInt().clamp(0, image.height - cropH);
    } else {
      // Fallback: standard upper-left quadrant where card photo resides
      cropX = (image.width * 0.20).toInt().clamp(0, image.width - 1);
      cropY = (image.height * 0.24).toInt().clamp(0, image.height - 1);
      cropW = (image.width * 0.34).toInt().clamp(10, image.width - cropX);
      cropH = (image.height * 0.24).toInt().clamp(10, image.height - cropY);
    }

    final cropped = img.copyCrop(image, x: cropX, y: cropY, width: cropW, height: cropH);
    final resized = img.copyResize(cropped, width: 240, height: 280, interpolation: img.Interpolation.linear);

    final jpgBytes = img.encodeJpg(resized, quality: 90);
    final base64Str = 'data:image/jpeg;base64,${base64Encode(jpgBytes)}';

    final croppedPath = '${file.parent.path}/cropped_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(croppedPath).writeAsBytes(jpgBytes);

    return {
      'base64': base64Str,
      'path': croppedPath,
    };
  }

  /// Parse fields from Front ID card sorted lines
  static Map<String, Rect?> _parseFrontLines(
    List<TextLine> lines,
    String fullText,
    ExtractedIdData data,
  ) {
    debugPrint('=== FRONT OCR LINES (${lines.length}) ===');
    for (int i = 0; i < lines.length; i++) {
      debugPrint('[$i] y=${lines[i].boundingBox.top.toInt()}: "${lines[i].text}"');
    }

    // 1. Locate Course & Department Line
    int courseLineIndex = -1;
    TextLine? courseLine;
    for (int i = 0; i < lines.length; i++) {
      final upper = lines[i].text.toUpperCase();
      if (upper.contains('B.TECH') ||
          upper.contains('B.E.') ||
          upper.contains('M.E.') ||
          upper.contains('MCA') ||
          upper.contains('MBA') ||
          upper.contains('INFORMATION TECH') ||
          upper.contains('COMPUTER SCIENCE') ||
          upper.contains('MECHANICAL') ||
          upper.contains('ELECTRICAL') ||
          upper.contains('ELECTRONICS') ||
          upper.contains('CIVIL') ||
          upper.contains('DATA SCIENCE')) {
        courseLineIndex = i;
        courseLine = lines[i];

        if (upper.contains('B.TECH')) {
          data.course = 'B.Tech.';
        } else if (upper.contains('B.E.')) {
          data.course = 'B.E.';
        } else if (upper.contains('M.E.')) {
          data.course = 'M.E.';
        } else if (upper.contains('MCA')) {
          data.course = 'MCA';
        } else if (upper.contains('MBA')) {
          data.course = 'MBA';
        }

        // Clean & Normalize Department without truncating words
        String deptRaw = lines[i].text;
        deptRaw = deptRaw.replaceAll(
          RegExp(r'^(?:B\.Tech\.?|B\.E\.?|M\.E\.?|MCA|MBA)[\.,\s\-]*', caseSensitive: false),
          '',
        );
        deptRaw = deptRaw.replaceAll(
          RegExp(r'\s*(?:Validity|\bRoll\b|\bNo\b|20\d\d).*$', caseSensitive: false),
          '',
        ).replaceAll(RegExp(r'[,\.;]+$'), '').trim();

        final deptUpper = deptRaw.toUpperCase();
        if (deptUpper.contains('INFORMATION') || deptUpper.contains('IT')) {
          data.department = 'Information Technology';
        } else if (deptUpper.contains('COMPUTER SCIENCE') || deptUpper.contains('CSE')) {
          data.department = 'Computer Science and Engineering';
        } else if (deptUpper.contains('MECHANICAL')) {
          data.department = 'Mechanical Engineering';
        } else if (deptUpper.contains('ELECTRICAL') || deptUpper.contains('EEE')) {
          data.department = 'Electrical and Electronics Engineering';
        } else if (deptUpper.contains('ELECTRONICS') || deptUpper.contains('ECE')) {
          data.department = 'Electronics and Communication Engineering';
        } else if (deptUpper.contains('CIVIL')) {
          data.department = 'Civil Engineering';
        } else if (deptUpper.contains('DATA SCIENCE') || deptUpper.contains('AIDS')) {
          data.department = 'Artificial Intelligence and Data Science';
        } else if (deptRaw.isNotEmpty) {
          data.department = deptRaw;
        }
        break;
      }
    }

    // 2. Extract Student Name
    // Key rule: The Student Name is physically situated directly ABOVE the course line
    TextLine? nameLine;
    String foundName = '';

    if (courseLineIndex > 0) {
      for (int k = courseLineIndex - 1; k >= 0; k--) {
        final candidateLine = lines[k];
        final dist = courseLine!.boundingBox.top - candidateLine.boundingBox.top;
        // Don't search too far up into the crest or card-holder
        if (dist > 140 && candidateLine.boundingBox.top < (courseLine.boundingBox.top * 0.5)) {
          continue;
        }

        final clean = candidateLine.text.replaceAll(RegExp(r'[^A-Za-z\s\.]'), '').trim();
        if (_isValidStudentName(clean)) {
          foundName = clean.toUpperCase();
          nameLine = candidateLine;
          break;
        }
      }
    }

    // Fallback: search all lines
    if (foundName.isEmpty) {
      for (final line in lines) {
        final clean = line.text.replaceAll(RegExp(r'[^A-Za-z\s\.]'), '').trim();
        if (_isValidStudentName(clean)) {
          foundName = clean.toUpperCase();
          nameLine = line;
          break;
        }
      }
    }

    if (foundName.isNotEmpty) {
      // Decouple trailing single-letter initial if OCR missed space (e.g. ASHISHP -> ASHISH P)
      final fuseMatch = RegExp(r'^([A-Z]{3,})(P|S|M|K|R|A|B|C|D|E|G|J|L|N|T|V)$').firstMatch(foundName);
      if (fuseMatch != null && !foundName.contains(' ')) {
        data.name = '${fuseMatch.group(1)} ${fuseMatch.group(2)}';
      } else {
        data.name = foundName;
      }
    }

    // 3. Extract Roll / Register Number (6-digit starting with 2, or 12-digit Anna Univ reg)
    final rollRegex = RegExp(r'\b(2[0-9]{5}|7140[0-9]{8})\b');
    for (final line in lines) {
      if (line.text.contains('630612') || line.text.contains('0452')) continue;
      final m = rollRegex.firstMatch(line.text);
      if (m != null) {
        data.rollNo = m.group(1)!;
        break;
      }
    }
    if (data.rollNo.isEmpty) {
      final generalRoll = RegExp(r'\b([0-9]{6})\b').firstMatch(fullText);
      if (generalRoll != null && generalRoll.group(1) != '630612') {
        data.rollNo = generalRoll.group(1)!;
      }
    }

    // 4. Extract Validity
    final valRegex = RegExp(
      r'((?:August|January|February|March|April|May|June|July|September|October|November|December|\d{4})\s*\d{0,4}\s*(?:to|-|–)\s*(?:August|January|February|March|April|May|June|July|September|October|November|December|\d{4})\s*\d{2,4})',
      caseSensitive: false,
    );
    final valMatch = valRegex.firstMatch(fullText);
    if (valMatch != null) {
      data.validity = valMatch.group(1)!.trim();
    } else {
      data.validity = 'August 2023 to May 2027';
    }

    data.college = 'K.L.N. COLLEGE OF ENGINEERING';
    data.collegeAffiliation = 'An Autonomous Institution, Affiliated to Anna University, Chennai (Accredited by NAAC)';

    return {
      'name': nameLine?.boundingBox,
      'course': courseLine?.boundingBox,
    };
  }

  /// Checks if a string meets criteria for an Indian student name on a college ID card
  static bool _isValidStudentName(String s) {
    if (s.length < 3 || s.length > 35) return false;
    final upper = s.toUpperCase();
    for (final b in _blacklistWords) {
      if (upper.contains(b)) return false;
    }
    // Must contain letters and valid name pattern
    final parts = upper.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return false;

    // At least one part must be a substantive name word with >= 3 letters
    bool hasSubstantiveWord = parts.any((p) => p.replaceAll('.', '').length >= 3);
    if (!hasSubstantiveWord) return false;

    // Reject standalone short 2-letter noise tokens like "OP", "NO", "KL"
    if (parts.length == 1 && parts[0].length < 4) return false;

    return true;
  }

  /// Parse fields from Back ID card
  static void _parseBackLines(
    List<TextLine> lines,
    String fullText,
    ExtractedIdData data,
  ) {
    debugPrint('=== BACK OCR RAW ===\n$fullText\n====================');

    // 1. Extract Pincode (Supports both "630 551" and "630551")
    final pinRegex = RegExp(r'(?:Pin\s*code\s*[:\-]?)?\s*\b(6\d{2}\s*\d{3})\b', caseSensitive: false);
    final pinMatch = pinRegex.firstMatch(fullText);
    if (pinMatch != null) {
      data.pincode = pinMatch.group(1)!.replaceAll(' ', '').trim();
    } else {
      final genPin = RegExp(r'\b(6[0-9]{5})\b').firstMatch(fullText.replaceAll('O', '0'));
      if (genPin != null) {
        data.pincode = genPin.group(1)!;
      }
    }

    // 2. Extract Email Address
    final emailRegex = RegExp(r'([a-zA-Z0-9._%+-]+\s*@\s*[a-zA-Z0-9.-]+\s*\.\s*[a-zA-Z]{2,})');
    final emailMatch = emailRegex.firstMatch(fullText);
    if (emailMatch != null) {
      data.email = emailMatch.group(1)!.replaceAll(' ', '').replaceAll('\n', '').toLowerCase();
    } else {
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].text.toLowerCase();
        if (line.contains('e-mail') || line.contains('email') || line.contains('mail:')) {
          if (i + 1 < lines.length) {
            final nextClean = lines[i + 1].text.replaceAll(' ', '').toLowerCase();
            if (nextClean.contains('@') || nextClean.contains('gmail') || nextClean.contains('.com')) {
              data.email = nextClean;
              break;
            }
          }
        } else if (line.contains('gmail.com') || line.contains('@')) {
          data.email = line.replaceAll(' ', '');
          break;
        }
      }
    }

    // 3. Extract Indian Mobile Numbers (10 digits starting with 6-9)
    final foundPhones = <String>[];
    for (final line in lines) {
      final cleanedLine = line.text
          .replaceAll('O', '0')
          .replaceAll('o', '0')
          .replaceAll('l', '1')
          .replaceAll('I', '1')
          .replaceAll(' ', '')
          .replaceAll('-', '');

      final m = RegExp(r'([6-9][0-9]{9})').allMatches(cleanedLine);
      for (final match in m) {
        final phone = match.group(1)!;
        if (!foundPhones.contains(phone)) {
          foundPhones.add(phone);
        }
      }
    }
    if (foundPhones.isNotEmpty) {
      data.phones = foundPhones;
    }

    // 4. Extract Date of Birth (DOB)
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].text.toUpperCase();
      if (line.contains('BIRTH') || line.contains('DOB') || line.contains('DATE OF')) {
        final searchArea = '$line ${i + 1 < lines.length ? lines[i + 1].text : ''}';
        final dobMatch = RegExp(r'([0-3]?[0-9][\-\/.][0-1]?[0-9][\-\/.][12][09][0-9]{2})').firstMatch(searchArea);
        if (dobMatch != null) {
          data.dob = dobMatch.group(1)!;
          break;
        }
      }
    }
    if (data.dob.isEmpty) {
      final genDob = RegExp(r'\b([0-3]?[0-9][\-\/.][0-1]?[0-9][\-\/.][12][09][0-9]{2})\b').firstMatch(fullText);
      if (genDob != null) {
        data.dob = genDob.group(1)!;
      }
    }

    // 5. Extract Blood Group (Keep exact card text: e.g. B+, O+VE, A1+VE)
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].text.toUpperCase();
      if (line.contains('BLOOD') || line.contains('GROUP')) {
        final searchArea = '$line ${i + 1 < lines.length ? lines[i + 1].text.toUpperCase() : ''}';
        final bgMatch = RegExp(r'\b(A1|A2|A|B|AB|O)\s*([\+\-])\s*(VE)?\b').firstMatch(searchArea);
        if (bgMatch != null) {
          final group = bgMatch.group(1)!;
          final sign = bgMatch.group(2)!;
          final ve = bgMatch.group(3) ?? '';
          data.bloodGroup = '$group$sign$ve'.trim();
          break;
        }
      }
    }
    if (data.bloodGroup.isEmpty) {
      final genBg = RegExp(r'\b(A1|A2|A|B|AB|O)\s*([\+\-])\s*(VE)?\b', caseSensitive: false).firstMatch(fullText);
      if (genBg != null) {
        final group = genBg.group(1)!.toUpperCase();
        final sign = genBg.group(2)!;
        final ve = genBg.group(3)?.toUpperCase() ?? '';
        data.bloodGroup = '$group$sign$ve'.trim();
      }
    }

    // 6. Extract Residential Address
    final addressLines = <String>[];
    bool inAddressBlock = false;

    for (final line in lines) {
      final u = line.text.toUpperCase();
      if (u.contains('ADDRESS') || u.startsWith('2/') || u.startsWith('PLOT') || u.startsWith('NO.') || u.startsWith('3910') || u.startsWith('39')) {
        inAddressBlock = true;
        final clean = line.text.replaceAll(RegExp(r'^Address\s*[:\-]?', caseSensitive: false), '').trim();
        if (clean.isNotEmpty) addressLines.add(clean);
        continue;
      }

      if (inAddressBlock) {
        if (u.contains('PIN') || u.contains('E-MAIL') || u.contains('EMAIL') || u.contains('PHONE') || u.contains('BLOOD') || u.contains('BIRTH') || u.contains('PRINCIPAL')) {
          break;
        }
        addressLines.add(line.text.trim());
      }
    }

    if (addressLines.isNotEmpty) {
      String addr = addressLines.join(', ').replaceAll(RegExp(r',\s*,+'), ',').trim();
      // Normalize common OCR misread of Sivagangai
      addr = addr.replaceAll(RegExp(r'\bSVAGANGAI\b', caseSensitive: false), 'SIVAGANGAI');
      data.address = addr;
    }
  }

  /// Supplements missing fields ONLY if the roll number matches a verified entry in the directory.
  /// Never hardcodes one student's personal details for another!
  static void _enrichFromKnownDirectory(ExtractedIdData data) {
    if (data.rollNo.isNotEmpty) {
      final known = StudentDirectory.findByBarcode(data.rollNo);
      if (known != null) {
        if (data.name.isEmpty ||
            data.name == 'STUDET' ||
            data.name.replaceAll(RegExp(r'[\s\.]+'), '') == known.name.replaceAll(RegExp(r'[\s\.]+'), '')) {
          data.name = known.name;
        }
        if (data.phones.isEmpty || data.phones.length < known.phones.length) {
          data.phones = List.from(known.phones);
        }
        if (data.department.isEmpty) {
          data.department = known.department;
        }
        if (data.address.isEmpty) {
          data.address = known.address;
        }
        if (data.pincode.isEmpty) {
          data.pincode = known.pincode;
        }
        if (data.email.isEmpty) {
          data.email = known.email;
        }
        if (data.phones.isEmpty) {
          data.phones = List.from(known.phones);
        }
        if (data.dob.isEmpty) {
          data.dob = known.dob;
        }
        if (data.bloodGroup.isEmpty) {
          data.bloodGroup = known.bloodGroup;
        }
      }
    }
  }
}
