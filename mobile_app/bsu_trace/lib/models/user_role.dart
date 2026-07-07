// lib/models/user_role.dart
enum UserRole { user, processor, signee, admin, ictAdmin }

extension RoleMapper on int {
  UserRole toRole() {
    switch (this) {
      case 1: return UserRole.user;
      case 2: return UserRole.processor;
      case 3: return UserRole.signee;
      case 4: return UserRole.admin;
      case 5: return UserRole.ictAdmin;
      default: return UserRole.user;
    }
  }
}