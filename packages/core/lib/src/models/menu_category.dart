enum MenuCategory {
  drinks('drinks', 'Drinks'),
  food('food', 'Food'),
  snacks('snacks', 'Snacks'),
  merch('merch', 'Merch');

  const MenuCategory(this.wireValue, this.label);

  final String wireValue;

  final String label;

  static MenuCategory? tryFromWire(Object? value) {
    for (final category in MenuCategory.values) {
      if (category.wireValue == value) return category;
    }
    return null;
  }

  static const MenuCategory fallback = MenuCategory.food;

  static MenuCategory fromWire(Object? value) => tryFromWire(value) ?? fallback;
}
