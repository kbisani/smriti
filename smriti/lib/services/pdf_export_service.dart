import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../models/sub_user_profile.dart';
import '../storage/qdrant_profile_service.dart';

class PDFExportService {
  static Future<File> exportTimelineAndGraphs(SubUserProfile profile) async {
    final pdf = pw.Document();
    final profileService = QdrantProfileService();
    
    try {
      await profileService.initialize();
      
      // Get all data
      final timelineData = await profileService.getTimelineData(profile.id);
      final mosaicData = await profileService.getMosaicData(profile.id);
      
      // Use default PDF font for now
      final font = pw.Font.helvetica();
      
      // Create the PDF document
      await _buildPDFDocument(pdf, profile, timelineData, mosaicData, font);
      
      // Save to file
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/${profile.name}_memories_${DateTime.now().millisecondsSinceEpoch}.pdf");
      await file.writeAsBytes(await pdf.save());
      
      return file;
    } catch (e) {
      print('Error creating PDF: $e');
      rethrow;
    }
  }
  
  static Future<void> _buildPDFDocument(
    pw.Document pdf,
    SubUserProfile profile,
    Map<int, List<Map<String, dynamic>>> timelineData,
    Map<String, List<Map<String, dynamic>>> mosaicData,
    pw.Font font,
  ) async {
    
    // Cover Page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return _buildCoverPage(profile, font);
        },
      ),
    );
    
    // Table of Contents
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return _buildTableOfContents(timelineData, mosaicData, font);
        },
      ),
    );
    
    // Memory Statistics Overview
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return _buildStatisticsPage(timelineData, mosaicData, font);
        },
      ),
    );
    
    // Timeline Section
    await _buildTimelineSection(pdf, timelineData, font);
    
    // Category Analysis Section
    await _buildCategorySection(pdf, mosaicData, font);
    
    // Individual Stories Section
    await _buildStoriesSection(pdf, timelineData, font);
  }
  
  static pw.Widget _buildCoverPage(SubUserProfile profile, pw.Font font) {
    final currentYear = DateTime.now().year;
    
    return pw.Container(
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
          colors: [
            PdfColor.fromHex('#667eea'),
            PdfColor.fromHex('#764ba2'),
          ],
        ),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(40),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(20),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  'Life Stories',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#667eea'),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  profile.name,
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 24,
                    fontWeight: pw.FontWeight.normal,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  profile.relation,
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 16,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Container(
                  width: 100,
                  height: 2,
                  color: PdfColor.fromHex('#667eea'),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'A collection of memories and reflections',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 14,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 40),
                pw.Text(
                  'Generated on ${DateTime.now().day}/${DateTime.now().month}/$currentYear',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 12,
                    color: PdfColors.grey500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  static pw.Widget _buildTableOfContents(
    Map<int, List<Map<String, dynamic>>> timelineData,
    Map<String, List<Map<String, dynamic>>> mosaicData,
    pw.Font font,
  ) {
    final totalMemories = timelineData.values.expand((e) => e).length;
    final yearSpan = timelineData.keys.isEmpty ? 0 : timelineData.keys.reduce((a, b) => a > b ? a : b) - 
                   timelineData.keys.reduce((a, b) => a < b ? a : b);
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Table of Contents',
          style: pw.TextStyle(
            font: font,
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#667eea'),
          ),
        ),
        pw.SizedBox(height: 30),
        
        _buildTOCItem('Memory Overview & Statistics', '3', font),
        _buildTOCItem('Timeline Visualization', '4', font),
        _buildTOCItem('Life Categories Analysis', '${4 + (timelineData.keys.length / 3).ceil()}', font),
        _buildTOCItem('Complete Story Collection', '${6 + (timelineData.keys.length / 3).ceil()}', font),
        
        pw.SizedBox(height: 40),
        
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#f8f9ff'),
            borderRadius: pw.BorderRadius.circular(10),
            border: pw.Border.all(color: PdfColor.fromHex('#667eea'), width: 1),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Collection Summary',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Total Memories: $totalMemories', style: pw.TextStyle(font: font, fontSize: 12)),
              pw.Text('Years Covered: $yearSpan years', style: pw.TextStyle(font: font, fontSize: 12)),
              pw.Text('Categories: ${mosaicData.values.where((stories) => stories.isNotEmpty).length}', 
                     style: pw.TextStyle(font: font, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
  
  static pw.Widget _buildTOCItem(String title, String page, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              title,
              style: pw.TextStyle(font: font, fontSize: 14),
            ),
          ),
          pw.Container(
            width: 100,
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    height: 1,
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(
                          color: PdfColors.grey400,
                          style: pw.BorderStyle.dotted,
                        ),
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Text(
                  page,
                  style: pw.TextStyle(font: font, fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  static pw.Widget _buildStatisticsPage(
    Map<int, List<Map<String, dynamic>>> timelineData,
    Map<String, List<Map<String, dynamic>>> mosaicData,
    pw.Font font,
  ) {
    final allMemories = timelineData.values.expand((e) => e).toList();
    final totalMemories = allMemories.length;
    final multiSessionStories = allMemories.where((m) => (m['session_count'] ?? 1) > 1).length;
    final averageWordsPerMemory = allMemories.isEmpty ? 0 : 
        allMemories.map((m) => (m['summary'] as String).split(' ').length).reduce((a, b) => a + b) / totalMemories;
    
    // Calculate memories per year
    final memoriesPerYear = <int, int>{};
    timelineData.forEach((year, memories) {
      memoriesPerYear[year] = memories.length;
    });
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Memory Collection Overview',
          style: pw.TextStyle(
            font: font,
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#667eea'),
          ),
        ),
        pw.SizedBox(height: 30),
        
        // Statistics Grid
        pw.Row(
          children: [
            pw.Expanded(
              child: _buildStatCard('Total Memories', totalMemories.toString(), font),
            ),
            pw.SizedBox(width: 20),
            pw.Expanded(
              child: _buildStatCard('Multi-Session Stories', multiSessionStories.toString(), font),
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Row(
          children: [
            pw.Expanded(
              child: _buildStatCard('Years Covered', timelineData.keys.length.toString(), font),
            ),
            pw.SizedBox(width: 20),
            pw.Expanded(
              child: _buildStatCard('Avg Words/Memory', averageWordsPerMemory.round().toString(), font),
            ),
          ],
        ),
        
        pw.SizedBox(height: 40),
        
        // Category Distribution
        pw.Text(
          'Memory Distribution by Category',
          style: pw.TextStyle(
            font: font,
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 20),
        
        pw.Column(
          children: mosaicData.entries.where((e) => e.value.isNotEmpty).map((entry) {
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Row(
                children: [
                  pw.Container(
                    width: 150,
                    child: pw.Text(
                      '${entry.key[0].toUpperCase()}${entry.key.substring(1)}',
                      style: pw.TextStyle(font: font, fontSize: 12),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Stack(
                      children: [
                        pw.Container(
                          height: 20,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey300,
                            borderRadius: pw.BorderRadius.circular(10),
                          ),
                        ),
                        pw.Container(
                          height: 20,
                          width: (entry.value.length / totalMemories) * 300, // Approximate width
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('#667eea'),
                            borderRadius: pw.BorderRadius.circular(10),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Text(
                    entry.value.length.toString(),
                    style: pw.TextStyle(font: font, fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
  
  static pw.Widget _buildStatCard(String title, String value, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#f8f9ff'),
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColor.fromHex('#667eea'), width: 1),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              font: font,
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#667eea'),
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            title,
            style: pw.TextStyle(
              font: font,
              fontSize: 12,
              color: PdfColors.grey600,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  static Future<void> _buildTimelineSection(
    pw.Document pdf,
    Map<int, List<Map<String, dynamic>>> timelineData,
    pw.Font font,
  ) async {
    final years = timelineData.keys.toList()..sort((a, b) => b.compareTo(a));
    
    for (int i = 0; i < years.length; i += 3) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            final pageYears = years.skip(i).take(3).toList();
            
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (i == 0) ...[
                  pw.Text(
                    'Timeline Overview',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#667eea'),
                    ),
                  ),
                  pw.SizedBox(height: 20),
                ],
                ...pageYears.map((year) => _buildYearSection(year, timelineData[year]!, font)),
              ],
            );
          },
        ),
      );
    }
  }
  
  static pw.Widget _buildYearSection(int year, List<Map<String, dynamic>> memories, pw.Font font) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 30),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#667eea'),
                  borderRadius: pw.BorderRadius.circular(20),
                ),
                child: pw.Text(
                  year.toString(),
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
              pw.SizedBox(width: 15),
              pw.Text(
                '${memories.length} ${memories.length == 1 ? 'memory' : 'memories'}',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 12,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 15),
          ...memories.take(3).map((memory) => _buildMemoryPreview(memory, font)),
          if (memories.length > 3)
            pw.Text(
              '... and ${memories.length - 3} more memories from this year',
              style: pw.TextStyle(
                font: font,
                fontSize: 10,
                color: PdfColors.grey500,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
  
  static pw.Widget _buildMemoryPreview(Map<String, dynamic> memory, pw.Font font) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  memory['summary'] ?? '',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.normal,
                  ),
                  maxLines: 2,
                ),
              ),
              if ((memory['session_count'] ?? 1) > 1) ...[
                pw.SizedBox(width: 10),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#667eea'),
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Text(
                    '${memory['session_count']} sessions',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 8,
                      color: PdfColors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
  
  static Future<void> _buildCategorySection(
    pw.Document pdf,
    Map<String, List<Map<String, dynamic>>> mosaicData,
    pw.Font font,
  ) async {
    final categoriesWithStories = mosaicData.entries.where((e) => e.value.isNotEmpty).toList();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Life Categories Analysis',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#667eea'),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Your memories organized by life themes and experiences',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 14,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(height: 30),
              
              pw.Wrap(
                spacing: 15,
                runSpacing: 15,
                children: categoriesWithStories.map((entry) {
                  return pw.Container(
                    width: 120,
                    padding: const pw.EdgeInsets.all(15),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#f8f9ff'),
                      borderRadius: pw.BorderRadius.circular(10),
                      border: pw.Border.all(color: PdfColor.fromHex('#667eea'), width: 1),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text(
                          '${entry.key[0].toUpperCase()}${entry.key.substring(1)}',
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          '${entry.value.length} ${entry.value.length == 1 ? 'story' : 'stories'}',
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 10,
                            color: PdfColors.grey600,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
  
  static Future<void> _buildStoriesSection(
    pw.Document pdf,
    Map<int, List<Map<String, dynamic>>> timelineData,
    pw.Font font,
  ) async {
    final allMemories = timelineData.values.expand((e) => e).toList()
      ..sort((a, b) => (b['year'] as int).compareTo(a['year'] as int));
    
    // Group stories for pagination (3-4 per page)
    for (int i = 0; i < allMemories.length; i += 3) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            final pageMemories = allMemories.skip(i).take(3).toList();
            
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (i == 0) ...[
                  pw.Text(
                    'Complete Story Collection',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#667eea'),
                    ),
                  ),
                  pw.SizedBox(height: 20),
                ],
                ...pageMemories.map((memory) => _buildFullStory(memory, font)),
              ],
            );
          },
        ),
      );
    }
  }
  
  static pw.Widget _buildFullStory(Map<String, dynamic> memory, pw.Font font) {
    final sessions = memory['sessions'] as List<Map<String, dynamic>>?;
    
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 30),
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColor.fromHex('#667eea'), width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Row(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#667eea'),
                  borderRadius: pw.BorderRadius.circular(15),
                ),
                child: pw.Text(
                  memory['year'].toString(),
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 12,
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              if ((memory['session_count'] ?? 1) > 1)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey300,
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Text(
                    '${memory['session_count']} sessions',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
            ],
          ),
          
          pw.SizedBox(height: 15),
          
          // Summary
          pw.Text(
            memory['summary'] ?? '',
            style: pw.TextStyle(
              font: font,
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          
          pw.SizedBox(height: 10),
          
          // Sessions content
          if (sessions != null && sessions.isNotEmpty) ...[
            ...sessions.map((session) => pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10),
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#f8f9ff'),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                session['transcript'] ?? '',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            )),
          ] else ...[
            // Single session story
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#f8f9ff'),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                'This memory is part of your story collection.',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 11,
                  color: PdfColors.grey600,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ),
          ],
          
          // Original prompt
          if (memory['original_prompt'] != null) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              'Prompted by: "${memory['original_prompt']}"',
              style: pw.TextStyle(
                font: font,
                fontSize: 9,
                color: PdfColors.grey500,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}