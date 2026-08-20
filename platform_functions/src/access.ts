import * as admin from 'firebase-admin';
import { HttpsError } from 'firebase-functions/v2/https';

export type PlatformRole =
  | 'super_admin'
  | 'finance_admin'
  | 'support_admin'
  | 'sales_admin'
  | 'analyst';

export type PlatformPermission =
  | 'dashboard.read'
  | 'business.read'
  | 'business.write'
  | 'transaction.read'
  | 'transaction.reconcile'
  | 'subscription.write'
  | 'plan.write'
  | 'analytics.read'
  | 'report.export'
  | 'monitoring.read'
  | 'admin.write';

const rolePermissions: Record<PlatformRole, ReadonlySet<PlatformPermission>> = {
  super_admin: new Set<PlatformPermission>([
    'dashboard.read',
    'business.read',
    'business.write',
    'transaction.read',
    'transaction.reconcile',
    'subscription.write',
    'plan.write',
    'analytics.read',
    'report.export',
    'monitoring.read',
    'admin.write',
  ]),
  finance_admin: new Set<PlatformPermission>([
    'dashboard.read',
    'business.read',
    'transaction.read',
    'transaction.reconcile',
    'subscription.write',
    'analytics.read',
    'report.export',
  ]),
  support_admin: new Set<PlatformPermission>([
    'dashboard.read',
    'business.read',
    'business.write',
    'transaction.read',
    'subscription.write',
  ]),
  sales_admin: new Set<PlatformPermission>([
    'dashboard.read',
    'business.read',
    'plan.write',
    'analytics.read',
    'report.export',
  ]),
  analyst: new Set<PlatformPermission>([
    'dashboard.read',
    'business.read',
    'transaction.read',
    'analytics.read',
    'report.export',
  ]),
};

export type PlatformContext = {
  uid: string;
  email: string;
  name: string;
  role: PlatformRole;
  permissions: PlatformPermission[];
};

export function isPlatformRole(value: unknown): value is PlatformRole {
  return typeof value === 'string' && value in rolePermissions;
}

export function permissionsFor(role: PlatformRole): PlatformPermission[] {
  return [...rolePermissions[role]];
}

export async function requirePlatformAdmin(
  db: FirebaseFirestore.Firestore,
  auth: { uid: string; token: Record<string, unknown> } | undefined,
  permission: PlatformPermission,
): Promise<PlatformContext> {
  if (!auth || auth.token.platformAdmin !== true) {
    throw new HttpsError(
      'permission-denied',
      'Tài khoản không có quyền quản trị hệ thống.',
    );
  }

  const profile = await db.collection('platformAdmins').doc(auth.uid).get();
  const data = profile.data();
  if (!profile.exists || data?.active !== true) {
    throw new HttpsError(
      'permission-denied',
      'Tài khoản quản trị đã bị vô hiệu hóa.',
    );
  }

  // Legacy platform admins predate roles and remain super admins.
  const role = isPlatformRole(data?.role) ? data.role : 'super_admin';
  if (!rolePermissions[role].has(permission)) {
    throw new HttpsError(
      'permission-denied',
      'Vai trò quản trị không có quyền thực hiện thao tác này.',
    );
  }

  return {
    uid: auth.uid,
    email: String(data?.email ?? auth.token.email ?? ''),
    name: String(data?.name ?? ''),
    role,
    permissions: permissionsFor(role),
  };
}

export const __testing = { isPlatformRole, permissionsFor };
