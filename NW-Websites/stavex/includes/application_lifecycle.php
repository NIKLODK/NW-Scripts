<?php
require_once __DIR__ . "/db.php";

function application_history_exists(): bool
{
    static $cached = null;
    if ($cached !== null) {
        return $cached;
    }
    $rows = db_fetch_all("SHOW TABLES LIKE 'application_history'");
    $cached = !empty($rows);
    return $cached;
}

function application_archive_by_id(int $applicationId, string $reason, ?string $deletedByDiscordId = null): bool
{
    if ($applicationId <= 0 || !application_history_exists()) {
        return false;
    }

    $rows = db_fetch_all(
        "SELECT a.id AS application_id, a.form_id, a.type, a.applicant_name, a.discord_user_id,
                a.content, a.staff_response, a.status, a.created_at, a.answered_at, a.updated_at, f.title AS form_title
         FROM applications a
         LEFT JOIN application_forms f ON f.id = a.form_id
         WHERE a.id = ?
         LIMIT 1",
        [$applicationId]
    );
    $application = $rows[0] ?? null;
    if (!$application) {
        return false;
    }

    $status = (string) ($application["status"] ?? "pending");
    $answeredAt = (string) ($application["answered_at"] ?? "");
    if ($answeredAt === "" && in_array($status, ["approved", "denied"], true)) {
        $answeredAt = (string) ($application["updated_at"] ?? "");
    }
    if ($answeredAt === "") {
        $answeredAt = null;
    }

    return db_execute(
        "INSERT INTO application_history (
            application_id, form_id, type, form_title, applicant_name, discord_user_id, content,
            staff_response, final_status, created_at, answered_at, archived_at, delete_reason, deleted_by_discord_id
         )
         VALUES (?, NULLIF(?, ''), ?, ?, ?, ?, ?, ?, ?, ?, NULLIF(?, ''), ?, ?, NULLIF(?, ''))
         ON DUPLICATE KEY UPDATE
            form_id = VALUES(form_id),
            type = VALUES(type),
            form_title = VALUES(form_title),
            applicant_name = VALUES(applicant_name),
            discord_user_id = VALUES(discord_user_id),
            content = VALUES(content),
            staff_response = VALUES(staff_response),
            final_status = VALUES(final_status),
            created_at = VALUES(created_at),
            answered_at = VALUES(answered_at),
            archived_at = VALUES(archived_at),
            delete_reason = VALUES(delete_reason),
            deleted_by_discord_id = VALUES(deleted_by_discord_id)",
        [
            (string) $application["application_id"],
            $application["form_id"] !== null ? (string) $application["form_id"] : "",
            (string) ($application["type"] ?? "general"),
            (string) ($application["form_title"] ?? ""),
            (string) ($application["applicant_name"] ?? ""),
            (string) ($application["discord_user_id"] ?? ""),
            (string) ($application["content"] ?? ""),
            (string) ($application["staff_response"] ?? ""),
            $status,
            (string) ($application["created_at"] ?? date("Y-m-d H:i:s")),
            $answeredAt ?? "",
            date("Y-m-d H:i:s"),
            $reason,
            $deletedByDiscordId ?? "",
        ]
    );
}

function application_archive_and_delete(int $applicationId, string $reason, ?string $deletedByDiscordId = null): bool
{
    if ($applicationId <= 0 || !application_history_exists()) {
        return false;
    }

    $connection = db();
    $connection->begin_transaction();

    $archived = application_archive_by_id($applicationId, $reason, $deletedByDiscordId);
    if (!$archived) {
        $connection->rollback();
        return false;
    }

    $deleted = db_execute("DELETE FROM applications WHERE id = ?", [(string) $applicationId]);
    if (!$deleted) {
        $connection->rollback();
        return false;
    }

    $connection->commit();
    return true;
}

function application_cleanup_answered(int $days = 3): int
{
    if ($days < 1) {
        $days = 1;
    }
    $cutoff = date("Y-m-d H:i:s", time() - ($days * 86400));
    $rows = db_fetch_all(
        "SELECT id
         FROM applications
         WHERE status IN ('approved', 'denied')
           AND COALESCE(answered_at, updated_at) <= ?",
        [$cutoff]
    );

    $deletedCount = 0;
    foreach ($rows as $row) {
        $applicationId = (int) ($row["id"] ?? 0);
        if ($applicationId <= 0) {
            continue;
        }
        if (application_archive_and_delete($applicationId, "auto_cleanup", null)) {
            $deletedCount++;
        }
    }

    return $deletedCount;
}
