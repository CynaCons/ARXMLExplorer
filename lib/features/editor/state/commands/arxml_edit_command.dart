abstract class ArxmlEditCommand {
  void apply();
  void revert();
  String description();
  bool isStructural() => false; // method form for easy override
}
