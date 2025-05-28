package com.javatodev.finance.common.audit;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.fasterxml.jackson.databind.ObjectMapper;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

/**
 * Centralized audit logging service to track all business-critical operations
 * and security events.
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class AuditService {

    private final ObjectMapper objectMapper;

    @Value("${spring.application.name}")
    private String applicationName;

    /**
     * Log a security-related event
     * 
     * @param event The type of security event
     * @param userId The user ID associated with the event (if applicable)
     * @param details Additional details about the event
     */
    public void logSecurityEvent(SecurityEventType event, String userId, Map<String, Object> details) {
        Map<String, Object> auditData = createBaseAuditData("SECURITY", event.name());
        auditData.put("userId", userId);
        auditData.put("details", details);

        logAuditEvent(auditData);
    }

    /**
     * Log a data access event
     * 
     * @param operation The type of data operation (READ, CREATE, UPDATE, DELETE)
     * @param resourceType The type of resource being accessed
     * @param resourceId The ID of the resource being accessed
     * @param userId The user ID performing the operation
     * @param success Whether the operation was successful
     * @param details Additional details about the access
     */
    public void logDataAccess(DataOperation operation, String resourceType, String resourceId, 
                               String userId, boolean success, Map<String, Object> details) {
        Map<String, Object> auditData = createBaseAuditData("DATA_ACCESS", operation.name());
        auditData.put("resourceType", resourceType);
        auditData.put("resourceId", resourceId);
        auditData.put("userId", userId);
        auditData.put("success", success);
        auditData.put("details", details);

        logAuditEvent(auditData);
    }

    /**
     * Log a financial transaction for audit purposes
     * 
     * @param transactionType The type of financial transaction
     * @param transactionId The ID of the transaction
     * @param userId The user ID performing the transaction
     * @param amount The transaction amount
     * @param currency The transaction currency
     * @param details Additional details about the transaction
     */
    public void logFinancialTransaction(String transactionType, String transactionId, String userId,
                                        Double amount, String currency, Map<String, Object> details) {
        Map<String, Object> auditData = createBaseAuditData("FINANCIAL", transactionType);
        auditData.put("transactionId", transactionId);
        auditData.put("userId", userId);
        auditData.put("amount", amount);
        auditData.put("currency", currency);
        auditData.put("details", details);

        logAuditEvent(auditData);
    }

    /**
     * Log an administrative operation
     * 
     * @param operation The type of administrative operation
     * @param userId The user ID performing the operation
     * @param target The target of the operation
     * @param details Additional details about the operation
     */
    public void logAdminOperation(String operation, String userId, String target, Map<String, Object> details) {
        Map<String, Object> auditData = createBaseAuditData("ADMIN", operation);
        auditData.put("userId", userId);
        auditData.put("target", target);
        auditData.put("details", details);

        logAuditEvent(auditData);
    }

    /**
     * Log a system event
     * 
     * @param eventType The type of system event
     * @param details Additional details about the event
     */
    public void logSystemEvent(String eventType, Map<String, Object> details) {
        Map<String, Object> auditData = createBaseAuditData("SYSTEM", eventType);
        auditData.put("details", details);

        logAuditEvent(auditData);
    }

    private Map<String, Object> createBaseAuditData(String category, String action) {
        Map<String, Object> auditData = new HashMap<>();
        auditData.put("timestamp", LocalDateTime.now().toString());
        auditData.put("service", applicationName);
        auditData.put("category", category);
        auditData.put("action", action);
        auditData.put("auditVersion", "1.0");

        return auditData;
    }

    private void logAuditEvent(Map<String, Object> auditData) {
        try {
            // Log in a structured format for easy parsing by ELK or other log analysis tools
            String auditJson = objectMapper.writeValueAsString(auditData);
            log.info("AUDIT: {}", auditJson);

            // In a production environment, you might want to send this to a dedicated audit log
            // system or database in addition to logging it locally
        } catch (Exception e) {
            log.error("Failed to log audit event", e);
        }
    }

    public enum SecurityEventType {
        LOGIN_SUCCESS,
        LOGIN_FAILURE,
        LOGOUT,
        PASSWORD_CHANGE,
        PASSWORD_RESET_REQUEST,
        PASSWORD_RESET_COMPLETE,
        ACCOUNT_LOCKED,
        ACCOUNT_UNLOCKED,
        PERMISSION_CHANGE,
        ROLE_CHANGE,
        API_KEY_GENERATED,
        API_KEY_REVOKED,
        SUSPICIOUS_ACTIVITY
    }

    public enum DataOperation {
        CREATE,
        READ,
        UPDATE,
        DELETE,
        EXPORT,
        IMPORT,
        QUERY
    }
}
