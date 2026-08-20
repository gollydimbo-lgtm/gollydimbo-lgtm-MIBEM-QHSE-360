import type { Prisma, PrismaClient } from "@prisma/client";
import { QualificationStatus } from "@prisma/client";

type Tx = Prisma.TransactionClient | PrismaClient;

interface RecordAttendanceInput {
  employeeId: string;
  attended?: boolean;
  evaluationScore?: number;
  evaluationComment?: string;
}

/**
 * Enregistre la présence à une session, et si `attended` est vrai, crée ou
 * met à jour l'EmployeeCompetency correspondante avec une date d'expiration
 * calculée à partir de Training.validityMonths (si définie).
 */
export async function recordTrainingAttendance(tx: Tx, sessionId: string, input: RecordAttendanceInput) {
  const session = await tx.trainingSession.findUniqueOrThrow({
    where: { id: sessionId },
    include: { training: true },
  });

  const attendance = await tx.trainingAttendance.create({
    data: {
      sessionId,
      employeeId: input.employeeId,
      attended: input.attended ?? true,
      evaluationScore: input.evaluationScore,
      evaluationComment: input.evaluationComment,
    },
  });

  let competencyId: string | null = null;
  if (attendance.attended) {
    const obtainedAt = session.sessionDate;
    const expiresAt = session.training.validityMonths
      ? new Date(obtainedAt.getTime() + session.training.validityMonths * 30 * 86_400_000)
      : null;

    const competency = await tx.employeeCompetency.create({
      data: {
        employeeId: input.employeeId,
        trainingId: session.trainingId,
        obtainedAt,
        expiresAt,
        status: QualificationStatus.VALIDE,
      },
    });
    competencyId = competency.id;
  }

  return { attendance, competencyId };
}
