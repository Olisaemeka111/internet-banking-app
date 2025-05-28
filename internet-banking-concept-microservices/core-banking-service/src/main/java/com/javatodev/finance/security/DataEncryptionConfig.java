package com.javatodev.finance.security;

import lombok.extern.slf4j.Slf4j;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.security.Key;
import java.security.NoSuchAlgorithmException;
import java.util.Base64;

@Slf4j
@Configuration
public class DataEncryptionConfig {

    @Value("${encrypt.key:}")
    private String encryptionKeyString;

    @Value("${encrypt.key.file:}")
    private String encryptionKeyFile;

    private static final String ALGORITHM = "AES";
    private static final String TRANSFORMATION = "AES/ECB/PKCS5Padding";

    @Bean
    public SecretKey encryptionKey() {
        try {
            byte[] keyBytes;

            // First priority: check for key file
            if (encryptionKeyFile != null && !encryptionKeyFile.isEmpty()) {
                File file = new File(encryptionKeyFile);
                if (file.exists()) {
                    keyBytes = Files.readAllBytes(Paths.get(encryptionKeyFile));
                    log.info("Using encryption key from file: {}", encryptionKeyFile);
                    return new SecretKeySpec(keyBytes, ALGORITHM);
                }
            }

            // Second priority: check for key in configuration
            if (encryptionKeyString != null && !encryptionKeyString.isEmpty()) {
                keyBytes = Base64.getDecoder().decode(encryptionKeyString);
                log.info("Using encryption key from configuration");
                return new SecretKeySpec(keyBytes, ALGORITHM);
            }

            // If no key is provided, generate a new one (not recommended for production)
            log.warn("No encryption key provided. Generating a new key - THIS SHOULD NOT HAPPEN IN PRODUCTION");
            KeyGenerator keyGenerator = KeyGenerator.getInstance(ALGORITHM);
            keyGenerator.init(256); // 256-bit AES key
            SecretKey key = keyGenerator.generateKey();

            // Log the key in development environments only
            if (!isProdEnvironment()) {
                log.warn("Generated encryption key (BASE64): {}", 
                         Base64.getEncoder().encodeToString(key.getEncoded()));
            }

            return key;
        } catch (NoSuchAlgorithmException | IOException e) {
            throw new RuntimeException("Failed to initialize encryption key", e);
        }
    }

    @Bean
    public EncryptionService encryptionService(SecretKey encryptionKey) {
        return new EncryptionService(encryptionKey);
    }

    private boolean isProdEnvironment() {
        String env = System.getProperty("spring.profiles.active");
        return env != null && env.contains("prod");
    }

    public static class EncryptionService {
        private final Key key;

        public EncryptionService(Key key) {
            this.key = key;
        }

        public String encrypt(String data) {
            try {
                Cipher cipher = Cipher.getInstance(TRANSFORMATION);
                cipher.init(Cipher.ENCRYPT_MODE, key);
                byte[] encryptedBytes = cipher.doFinal(data.getBytes(StandardCharsets.UTF_8));
                return Base64.getEncoder().encodeToString(encryptedBytes);
            } catch (Exception e) {
                throw new RuntimeException("Encryption failed", e);
            }
        }

        public String decrypt(String encryptedData) {
            try {
                Cipher cipher = Cipher.getInstance(TRANSFORMATION);
                cipher.init(Cipher.DECRYPT_MODE, key);
                byte[] decryptedBytes = cipher.doFinal(Base64.getDecoder().decode(encryptedData));
                return new String(decryptedBytes, StandardCharsets.UTF_8);
            } catch (Exception e) {
                throw new RuntimeException("Decryption failed", e);
            }
        }
    }
}
