// Shapes of the Firestore documents shared with the CampusBell app
// (see lib/models/models.dart in the Flutter project).

export type Role = "HOD" | "Professor" | "Assistant" | "Student" | "Administrator";

export interface AppUser {
  uid: string;
  name: string;
  email: string;
  username?: string | null;
  department: string;
  role: Role;
  staffId?: string | null;
  status: "active" | "disabled";
}

export type BellStatus =
  | "pending"
  | "delivered"
  | "accepted"
  | "declined"
  | "failed"
  | "rejected";

export interface BellRequest {
  id: string;
  senderUid: string;
  senderName: string;
  senderRole: string;
  recipientUid: string;
  recipientName: string;
  recipientRole: string;
  message: string;
  priority: "normal" | "high" | "urgent";
  status: BellStatus;
  reason?: string | null;
  createdAt?: Date;
}
