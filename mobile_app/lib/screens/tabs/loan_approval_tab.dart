import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/models/loan_application.dart';
import 'package:mobile_app/services/api_service.dart';

class LoanApprovalTab extends StatefulWidget {
  const LoanApprovalTab({super.key});

  @override
  State<LoanApprovalTab> createState() => _LoanApprovalTabState();
}

class _LoanApprovalTabState extends State<LoanApprovalTab> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  bool _isLoading = false;
  
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // Controllers
  final _cibilController = TextEditingController();
  final _loanTermController = TextEditingController();
  final _loanAmountController = TextEditingController();
  final _incomeController = TextEditingController();
  final _bankAssetController = TextEditingController();
  final _residentialAssetController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3), // Start slightly below
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic, // Smooth pop-up curve
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cibilController.dispose();
    _loanTermController.dispose();
    _loanAmountController.dispose();
    _incomeController.dispose();
    _bankAssetController.dispose();
    _residentialAssetController.dispose();
    super.dispose();
  }

  Future<void> _submitLoanApplication() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final application = LoanApplication(
        cibilScore: int.parse(_cibilController.text),
        loanTerm: int.parse(_loanTermController.text),
        loanAmount: int.parse(_loanAmountController.text),
        incomeAnnum: int.parse(_incomeController.text),
        bankAssetValue: int.parse(_bankAssetController.text),
        residentialAssetsValue: int.parse(_residentialAssetController.text),
      );

      try {
        // Parallel execution: API call + Minimum wait
        // This ensures meaningful loading time but doesn't block if API is slow
        final apiCall = _apiService.predictLoan(application);
        final minimumWait = Future.delayed(const Duration(seconds: 4));
        
        final results = await Future.wait([apiCall, minimumWait]);
        final result = results[0] as Map<String, dynamic>;

        // Assuming result has a 'status' or 'prediction' field. 
        // Adjust based on actual API response format.
        if (mounted) _showResultSheet(result);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showResultSheet(Map<String, dynamic> result) {
    // Example: API returns {"loan_status": "Approved"} or similar
    final isApproved = result.toString().toLowerCase().contains("approved"); 
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E).withOpacity(0.95), // Dark background
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          boxShadow: [
             BoxShadow(
               color: isApproved ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
               blurRadius: 40,
               spreadRadius: 5,
             )
          ],
          border: Border(
            top: BorderSide(
              color: isApproved ? Colors.green.withOpacity(0.5) : Colors.red.withOpacity(0.5),
              width: 1,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 30),
            
            // Asset GIF
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isApproved ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isApproved ? Colors.green.withOpacity(0.5) : Colors.red.withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: Icon(
                isApproved ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: isApproved ? Colors.greenAccent : Colors.redAccent,
                size: 50,
              ),
            ),
            const SizedBox(height: 20),
            
            // Title
            Text(
              isApproved ? "Loan Approved!" : "Application Rejected",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            
            // Subtitle / Reason
            Text(
              isApproved 
                  ? "Congratulations! You are eligible for this loan." 
                  : "Unfortunately, you do not meet the criteria at this time.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  "Dismiss",
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12.0, bottom: 8.0),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold, // Increased to bold
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          // Glassmorphism effect
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.4), // Higher opacity for cleaner look
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.6),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.inter(
                    color: Colors.black, // Black text
                    fontWeight: FontWeight.w800, // Increased to Extra Bold
                    fontSize: 16,
                  ),
                  cursorColor: Colors.black,
                  decoration: InputDecoration(
                    hintText: "Enter $label", // Use label as hint
                    hintStyle: GoogleFonts.inter(
                      color: Colors.black.withOpacity(0.4),
                      fontWeight: FontWeight.bold, // Increased to bold
                    ),
                    // Styled Icon
                    prefixIcon: Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.1), // Light blackish background
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: Colors.black, size: 20), // Bold black icon
                    ),
                    suffixText: suffix,
                    suffixStyle: GoogleFonts.inter(
                      color: Colors.black.withOpacity(0.7),
                      fontWeight: FontWeight.bold, // Increased to bold
                    ),
                    border: InputBorder.none,
                    filled: false, // Prevents theme's grey box
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (int.tryParse(value) == null) return 'Invalid number';
                    return null;
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Section Header Helper
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 5.0),
      child: Text(
        title,
        style: GoogleFonts.inter(
          color: Colors.white, // Changed to white as requested
          fontSize: 22, // Increased size
          fontWeight: FontWeight.w900, // Extra bold
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20), // Top margin since header is gone

              // Master Glass Card
              ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // Increased blur for better transparency
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12), // More translucent / thin glass
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                      boxShadow: [
                         BoxShadow(
                           color: Colors.black.withOpacity(0.05),
                           blurRadius: 25,
                           offset: const Offset(0, 10),
                         ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader("Financial Details"),
                        const SizedBox(height: 10),
                        
                        _buildGlassTextField(
                          controller: _cibilController,
                          label: "CIBIL Score",
                          icon: Icons.speed_rounded,
                        ),
                        
                        Row(
                          children: [
                            Expanded(
                              child: _buildGlassTextField(
                                controller: _loanTermController,
                                label: "Term (Mo)",
                                icon: Icons.calendar_today_rounded,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildGlassTextField(
                                controller: _loanAmountController,
                                label: "Amount",
                                icon: Icons.monetization_on_rounded,
                                suffix: "₹",
                              ),
                            ),
                          ],
                        ),

                        _buildGlassTextField(
                          controller: _incomeController,
                          label: "Annual Income",
                          icon: Icons.account_balance_wallet_outlined,
                          suffix: "₹",
                        ),
                        
                        const SizedBox(height: 20),
                        _buildSectionHeader("Assets"),
                        const SizedBox(height: 10),

                        _buildGlassTextField(
                          controller: _bankAssetController,
                          label: "Bank Assets",
                          icon: Icons.savings_outlined,
                          suffix: "₹",
                        ),

                        _buildGlassTextField(
                          controller: _residentialAssetController,
                          label: "Residential Assets",
                          icon: Icons.home_work_outlined,
                          suffix: "₹",
                        ),

                        const SizedBox(height: 20),

                        // Action Button - Now Inside the Card
                        Container(
                          width: double.infinity,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              )
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.8), // Darker for better contrast inside light card
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _submitLoanApplication,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              "Check Approval",
                                              style: GoogleFonts.inter(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 120), // Bottom padding for NavBar
            ],
          ),
        ),
          ),
        ),
      ),
    );
  }
}
