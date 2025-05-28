// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/screens/ai_studio_home_page.dart';
import 'presentation/providers/settings_provider.dart'; // To get theme mode
import 'presentation/widgets/canvas_mode_navigator.dart';
import 'package:google_fonts/google_fonts.dart';

class AiStudioCloneApp extends ConsumerWidget { // Use ConsumerWidget
  const AiStudioCloneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) { // Add WidgetRef
    // Watch the theme mode provider
    final themeMode = ref.watch(themeModeProvider);
    
    return MaterialApp(
      
      title: 'AI Studio Clone',
      themeMode: themeMode, // Set theme mode dynamically
      // Define Light Theme
      theme: AppThemes.lightTheme,
    
      // Define Dark Theme
      darkTheme: AppThemes.darkTheme,
      // Define Fantasy Theme
      highContrastDarkTheme: AppThemes.fantasyTheme,
      // Home Page wrapped with canvas mode navigator
      home: const CanvasModeNavigator(
        child: AiStudioHomePage(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
class AppThemes {
  // --- Refined Dark Theme ---
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFF1A1B1E), // Slightly less black, richer dark
    primaryColor: const Color(0xFF8C61FF), // Primary accent (purple)
    hintColor: Colors.grey[500],
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFF8C61FF),      // Used by ElevatedButton, FloatingActionButton etc.
      secondary: const Color(0xFF7D50E6),    // A slightly deeper purple for secondary elements
      surface: const Color(0xFF232529),      // Surfaces like AppBar, Card background (subtly distinct from scaffold)
      surfaceVariant: const Color(0xFF2A2C30),// For elements like filled input fields
      onPrimary: Colors.white,               // Text/icons on primary color
      onSecondary: Colors.white,             // Text/icons on secondary color
      onSurface: Colors.grey[200]!,          // Text/icons on surface color (lighter for better contrast)
      onSurfaceVariant: Colors.grey[400]!,   // Text/icons on surfaceVariant
      error: const Color(0xFFCF6679),        // Standard Material dark error
      onError: Colors.black,                 // Text on error
      background: const Color(0xFF1A1B1E),    // Same as scaffold
      onBackground: Colors.grey[200]!,       // Text on background
      brightness: Brightness.dark,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF232529), // Consistent with surface
      elevation: 0,
      scrolledUnderElevation: 1,
      iconTheme: IconThemeData(color: Colors.grey[300]),
      titleTextStyle: GoogleFonts.inter(
          color: Colors.grey[100], fontSize: 18, fontWeight: FontWeight.w600),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2A2C30), // Consistent with surfaceVariant
      hintStyle: GoogleFonts.inter(color: Colors.grey[500]),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), // Slightly larger radius
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[700]!, width: 0.5), // Subtle border
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF8C61FF), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF8C61FF),   // Button background
        foregroundColor: Colors.white,              // Button text/icon color
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, letterSpacing: 0.5),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF8C61FF),
        side: const BorderSide(color: Color(0xFF8C61FF), width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, letterSpacing: 0.5),
      )
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF8C61FF),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
      )
    ),
    textTheme: TextTheme(
      displayLarge: GoogleFonts.inter(color: Colors.grey[200], fontWeight: FontWeight.bold),
      displayMedium: GoogleFonts.inter(color: Colors.grey[200], fontWeight: FontWeight.bold),
      displaySmall: GoogleFonts.inter(color: Colors.grey[200], fontWeight: FontWeight.bold),
      headlineMedium: GoogleFonts.inter(color: Colors.grey[200], fontWeight: FontWeight.w600),
      headlineSmall: GoogleFonts.inter(color: Colors.grey[200], fontWeight: FontWeight.w600),
      titleLarge: GoogleFonts.inter(color: Colors.grey[100], fontWeight: FontWeight.w600),
      titleMedium: GoogleFonts.inter(color: Colors.grey[200], fontWeight: FontWeight.w500),
      titleSmall: GoogleFonts.inter(color: Colors.grey[300], fontWeight: FontWeight.w500),
      bodyLarge: GoogleFonts.inter(color: Colors.grey[300], fontSize: 16, height: 1.5),
      bodyMedium: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14, height: 1.5),
      bodySmall: GoogleFonts.inter(color: Colors.grey[500], fontSize: 12, height: 1.4),
      labelLarge: GoogleFonts.inter(color: Colors.grey[200], fontWeight: FontWeight.w600),
      labelMedium: GoogleFonts.inter(color: Colors.grey[400], fontSize: 12),
      labelSmall: GoogleFonts.inter(color: Colors.grey[500], fontSize: 11, letterSpacing: 0.5),
    ).apply(
      bodyColor: Colors.grey[300],
      displayColor: Colors.grey[200],
    ),
    iconTheme: IconThemeData(color: Colors.grey[400]),
    dividerColor: Colors.grey[800],
    cardTheme: CardThemeData(
      elevation: 0.5,
      color: const Color(0xFF232529), // Consistent with surface
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[800]!, width: 0.5),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: Colors.grey[400],
      titleTextStyle: GoogleFonts.inter(fontSize: 15, color: Colors.grey[200]),
      subtitleTextStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500]),
      selectedColor: Colors.white,
      selectedTileColor: const Color(0xFF8C61FF).withOpacity(0.2),
      dense: true,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF2A2C30),
      labelStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey[300]),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey[700]!),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      selectedColor: const Color(0xFF8C61FF),
      secondarySelectedColor: Colors.white, // Text color when selected
      secondaryLabelStyle: GoogleFonts.inter(fontSize: 13, color: Colors.white),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF232529),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: GoogleFonts.inter(fontSize: 18, color: Colors.grey[100], fontWeight: FontWeight.w600),
      contentTextStyle: GoogleFonts.inter(fontSize: 15, color: Colors.grey[300]),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: const Color(0xFF232529),
      selectedItemColor: const Color(0xFF8C61FF),
      unselectedItemColor: Colors.grey[500],
      selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.inter(),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor:const Color(0xFF8C61FF),
      unselectedLabelColor: Colors.grey[400],
      indicatorColor: const Color(0xFF8C61FF),
      labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.inter(),
    )
  );

  // --- Light Theme Definition ---
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFF7F7FA), // Very light gray, almost white
    primaryColor: const Color(0xFF6A11CB), // A nice vibrant purple for light theme
    hintColor: Colors.grey[500],
    colorScheme: ColorScheme.light(
      primary: const Color(0xFF6A11CB),        // Main purple
      secondary: const Color(0xFF8E2DE2),      // A complementary lighter purple or vibrant blue
      surface: Colors.white,                   // Surfaces like AppBar (if flat), Card background
      surfaceVariant: Colors.grey[100]!,       // For elements like filled input fields
      onPrimary: Colors.white,                 // Text/icons on primary color
      onSecondary: Colors.white,               // Text/icons on secondary color
      onSurface: Colors.grey[800]!,            // Text/icons on surface color
      onSurfaceVariant: Colors.grey[600]!,     // Text/icons on surfaceVariant
      error: const Color(0xFFB00020),          // Standard Material light error
      onError: Colors.white,                   // Text on error
      background: const Color(0xFFF7F7FA),      // Same as scaffold
      onBackground: Colors.grey[850]!,         // Text on background
      brightness: Brightness.light,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white, // Clean white AppBar
      elevation: 0.5,
      scrolledUnderElevation: 1,
      surfaceTintColor: Colors.transparent, // Avoids tinting on scroll with M3
      iconTheme: IconThemeData(color: Colors.grey[700]),
      titleTextStyle: GoogleFonts.lato(
          color: Colors.grey[900], fontSize: 18, fontWeight: FontWeight.w600),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey[100],
      hintStyle: GoogleFonts.lato(color: Colors.grey[500]),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6A11CB), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6A11CB),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: GoogleFonts.lato(fontWeight: FontWeight.w700, letterSpacing: 0.5),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF6A11CB),
        side: const BorderSide(color: Color(0xFF6A11CB), width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: GoogleFonts.lato(fontWeight: FontWeight.w700, letterSpacing: 0.5),
      )
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF6A11CB),
        textStyle: GoogleFonts.lato(fontWeight: FontWeight.w700),
      )
    ),
    textTheme: TextTheme(
      displayLarge: GoogleFonts.lato(color: Colors.grey[900], fontWeight: FontWeight.bold),
      displayMedium: GoogleFonts.lato(color: Colors.grey[900], fontWeight: FontWeight.bold),
      displaySmall: GoogleFonts.lato(color: Colors.grey[900], fontWeight: FontWeight.bold),
      headlineMedium: GoogleFonts.lato(color: Colors.grey[850], fontWeight: FontWeight.w600),
      headlineSmall: GoogleFonts.lato(color: Colors.grey[850], fontWeight: FontWeight.w600),
      titleLarge: GoogleFonts.lato(color: Colors.grey[800], fontWeight: FontWeight.w600),
      titleMedium: GoogleFonts.lato(color: Colors.grey[700], fontWeight: FontWeight.w500),
      titleSmall: GoogleFonts.lato(color: Colors.grey[600], fontWeight: FontWeight.w500),
      bodyLarge: GoogleFonts.lato(color: Colors.grey[800], fontSize: 16, height: 1.5),
      bodyMedium: GoogleFonts.lato(color: Colors.grey[700], fontSize: 14, height: 1.5),
      bodySmall: GoogleFonts.lato(color: Colors.black54, fontSize: 12, height: 1.4),
      labelLarge: GoogleFonts.lato(color: Colors.grey[800], fontWeight: FontWeight.w700),
      labelMedium: GoogleFonts.lato(color: Colors.grey[600], fontSize: 12),
      labelSmall: GoogleFonts.lato(color: Colors.grey[500], fontSize: 11, letterSpacing: 0.5),
    ).apply(
      bodyColor: Colors.grey[800],
      displayColor: Colors.grey[900],
    ),
    iconTheme: IconThemeData(color: Colors.grey[600]),
    dividerColor: Colors.grey[300],
    cardTheme: CardThemeData(
      elevation: 0.5,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: Colors.grey[600],
      titleTextStyle: GoogleFonts.lato(fontSize: 15, color: Colors.grey[800]),
      subtitleTextStyle: GoogleFonts.lato(fontSize: 13, color: Colors.grey[600]),
      selectedColor: const Color(0xFF6A11CB),
      selectedTileColor: const Color(0xFF6A11CB).withOpacity(0.1),
      dense: true,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.grey[200],
      labelStyle: GoogleFonts.lato(fontSize: 13, color: Colors.grey[700]),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      selectedColor: const Color(0xFF6A11CB),
      secondarySelectedColor: Colors.white, // Text color when selected
      secondaryLabelStyle: GoogleFonts.lato(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),

    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: GoogleFonts.lato(fontSize: 18, color: Colors.grey[900], fontWeight: FontWeight.w600),
      contentTextStyle: GoogleFonts.lato(fontSize: 15, color: Colors.grey[700]),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF6A11CB),
      unselectedItemColor: Colors.grey[500],
      selectedLabelStyle: GoogleFonts.lato(fontWeight: FontWeight.w700),
      unselectedLabelStyle: GoogleFonts.lato(),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: const Color(0xFF6A11CB),
      unselectedLabelColor: Colors.grey[600],
      indicatorColor: const Color(0xFF6A11CB),
      labelStyle: GoogleFonts.lato(fontWeight: FontWeight.w700),
      unselectedLabelStyle: GoogleFonts.lato(),
    )
  );

  // --- Fantasy Theme Definition (Polished) ---
  static final ThemeData fantasyTheme = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFF1A0A2A), // Deep purple/indigo background
    primaryColor: const Color(0xFFE040FB),           // Vibrant Magenta/Pink
    hintColor: const Color(0xFF00E5FF),               // Bright Cyan for accents/hints
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFE040FB),                // Magenta
      secondary: Color(0xFF7B1FA2),              // Deep Purple for secondary elements (more contrast than cyan here)
      surface: Color(0xFF2E1C41),                // Darker purple surface (for cards, app bars)
      surfaceVariant: Color(0xFF3A2650),          // Slightly lighter purple for input backgrounds
      onPrimary: Colors.black,                   // Text on Magenta (ensure good contrast)
      onSecondary: Colors.white,                 // Text on Deep Purple
      onSurface: Color(0xFFE6E0FF),              // Light Lavender text on surface
      onSurfaceVariant: Color(0xFFD1C4E9),        // Lighter lavender for text on input fields
      error: Color(0xFFFF6E6E),                  // A fantasy-ish bright red error
      onError: Colors.black,
      background: Color(0xFF1A0A2A),              // Same as scaffold
      onBackground: Color(0xFFE6E0FF),
      brightness: Brightness.dark,
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF2E1C41), // Darker purple AppBar
      elevation: 2,
      scrolledUnderElevation: 4,
      shadowColor: const Color(0xFFE040FB).withOpacity(0.3),
      iconTheme: IconThemeData(color: const Color(0xFF00E5FF).withOpacity(0.9)), // Cyan icons
      titleTextStyle: GoogleFonts.cinzelDecorative(
        color: const Color(0xFFE6E0FF),
        fontSize: 20,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(blurRadius: 5.0, color: const Color(0xFFE040FB).withOpacity(0.6), offset: const Offset(1, 1))
        ],
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF3A2650),       // Slightly lighter purple input bg (surfaceVariant)
      hintStyle: GoogleFonts.imFellEnglishSc(color: const Color(0xFF00E5FF).withOpacity(0.7), fontSize: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20), // Rounded corners
        borderSide: BorderSide(color: const Color(0xFFE040FB).withOpacity(0.4)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: const Color(0xFFE040FB).withOpacity(0.4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 2), // Cyan focus border
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFE040FB), // Magenta button bg
        foregroundColor: Colors.black,             // Black text on button
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30), // Pill shaped
        ),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
        textStyle: GoogleFonts.cinzel(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
        elevation: 6,
        shadowColor: Colors.black.withOpacity(0.7),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF00E5FF),
          side: BorderSide(color: const Color(0xFF00E5FF).withOpacity(0.8), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30), // Pill shaped
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
          textStyle: GoogleFonts.cinzel(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
        )
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF00E5FF),
        textStyle: GoogleFonts.cinzel(fontWeight: FontWeight.w600),
      )
    ),

    textTheme: TextTheme(
      displayLarge: GoogleFonts.uncialAntiqua(color: const Color(0xFFE6E0FF), fontWeight: FontWeight.bold),
      displayMedium: GoogleFonts.uncialAntiqua(color: const Color(0xFFE6E0FF), fontWeight: FontWeight.bold),
      displaySmall: GoogleFonts.uncialAntiqua(color: const Color(0xFFE6E0FF), fontWeight: FontWeight.bold),
      headlineMedium: GoogleFonts.cinzelDecorative(color: const Color(0xFFE6E0FF), fontWeight: FontWeight.w600),
      headlineSmall: GoogleFonts.cinzelDecorative(color: const Color(0xFFE6E0FF), fontWeight: FontWeight.w600),
      titleLarge: GoogleFonts.cinzel(color: const Color(0xFFEBE0FF), fontWeight: FontWeight.bold),
      titleMedium: GoogleFonts.cinzel(color: const Color(0xFFE6E0FF), fontWeight: FontWeight.w600),
      titleSmall: GoogleFonts.cinzel(color: const Color(0xFFD1C4E9), fontWeight: FontWeight.w500),
      bodyLarge: GoogleFonts.imFellEnglish(color: const Color(0xFFE6E0FF), fontSize: 17, height: 1.65),
      bodyMedium: GoogleFonts.imFellEnglish(color: const Color(0xFFD1C4E9), fontSize: 15, height: 1.6),
      bodySmall: GoogleFonts.imFellEnglish(color: const Color(0xFF00E5FF).withOpacity(0.85), fontSize: 13, height: 1.5),
      labelLarge: GoogleFonts.cinzel(color: const Color(0xFFEBE0FF), fontWeight: FontWeight.bold),
      labelMedium: GoogleFonts.imFellEnglish(color: const Color(0xFF00E5FF).withOpacity(0.9), fontSize: 12),
      labelSmall: GoogleFonts.imFellEnglish(color: const Color(0xFF00E5FF).withOpacity(0.7), fontSize: 11, letterSpacing: 0.5),
    ).apply(
      bodyColor: const Color(0xFFE6E0FF),
      displayColor: const Color(0xFFEBE0FF),
    ),

    iconTheme: IconThemeData(color: const Color(0xFF00E5FF).withOpacity(0.85)), // Cyan default icons
    dividerColor: const Color(0xFFE040FB).withOpacity(0.25),

    cardTheme: CardThemeData(
      elevation: 1,
      color: const Color(0xFF2E1C41), // Consistent with surface
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFFE040FB).withOpacity(0.3), width: 1),
      ),
      shadowColor: const Color(0xFFE040FB).withOpacity(0.1),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: const Color(0xFF00E5FF).withOpacity(0.8),
      titleTextStyle: GoogleFonts.imFellEnglish(fontSize: 15, color: const Color(0xFFE6E0FF)),
      subtitleTextStyle: GoogleFonts.imFellEnglish(fontSize: 13, color: const Color(0xFF00E5FF).withOpacity(0.7)),
      selectedTileColor: const Color(0xFFE040FB).withOpacity(0.15),
      selectedColor: const Color(0xFFEBE0FF), // Text color for selected item
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      dense: false,
    ),

    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF3A2650),
      labelStyle: GoogleFonts.cinzel(fontSize: 13, color: const Color(0xFFE6E0FF), fontWeight: FontWeight.w500),
      shape: StadiumBorder( // Rounded chip
        side: BorderSide(color: const Color(0xFFE040FB).withOpacity(0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      selectedColor: const Color(0xFFE040FB),
      secondarySelectedColor: Colors.black, // Text color when selected
      secondaryLabelStyle: GoogleFonts.cinzel(fontSize: 13, color: Colors.black, fontWeight: FontWeight.bold),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF2E1C41),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: const Color(0xFFE040FB).withOpacity(0.4))
      ),
      titleTextStyle: GoogleFonts.cinzelDecorative(fontSize: 19, color: const Color(0xFFEBE0FF), fontWeight: FontWeight.bold),
      contentTextStyle: GoogleFonts.imFellEnglish(fontSize: 16, color: const Color(0xFFD1C4E9)),
    ),
     bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: const Color(0xFF2A183E), // Slightly darker than AppBar for depth
      selectedItemColor: const Color(0xFF00E5FF),
      unselectedItemColor: const Color(0xFFE040FB).withOpacity(0.6),
      selectedLabelStyle: GoogleFonts.cinzel(fontWeight: FontWeight.bold),
      unselectedLabelStyle: GoogleFonts.cinzel(),
      elevation: 8,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: const Color(0xFF00E5FF),
      unselectedLabelColor: const Color(0xFFE040FB).withOpacity(0.7),
      indicator: UnderlineTabIndicator(
        borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 3),
        insets: const EdgeInsets.symmetric(horizontal:16.0)
      ),
      labelStyle: GoogleFonts.cinzel(fontWeight: FontWeight.bold),
      unselectedLabelStyle: GoogleFonts.cinzel(),
    )
  );
}