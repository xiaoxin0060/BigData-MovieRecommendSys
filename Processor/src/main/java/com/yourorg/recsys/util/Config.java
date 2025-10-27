package com.yourorg.recsys.util;

import org.yaml.snakeyaml.Yaml;

import java.io.InputStream;
import java.util.Map;

public class Config {
    private final Map<String, Object> root;

    @SuppressWarnings("unchecked")
    public Config(String resourcePath) {
        Yaml yaml = new Yaml();
        try (InputStream in = Config.class.getClassLoader().getResourceAsStream(resourcePath)) {
            if (in == null) {
                throw new IllegalArgumentException("Config resource not found: " + resourcePath);
            }
            this.root = yaml.load(in);
        } catch (Exception e) {
            throw new RuntimeException("Failed to load config: " + resourcePath, e);
        }
    }

    @SuppressWarnings("unchecked")
    public Map<String, Object> getSection(String key) {
        Object value = root.get(key);
        if (value == null) return null;
        if (!(value instanceof Map)) return null;
        return (Map<String, Object>) value;
    }

    public String getString(String dottedKey, String defaultValue) {
        Object val = get(dottedKey);
        return val == null ? defaultValue : String.valueOf(val);
    }

    public int getInt(String dottedKey, int defaultValue) {
        Object val = get(dottedKey);
        if (val == null) return defaultValue;
        if (val instanceof Number) return ((Number) val).intValue();
        return Integer.parseInt(String.valueOf(val));
    }

    public long getLong(String dottedKey, long defaultValue) {
        Object val = get(dottedKey);
        if (val == null) return defaultValue;
        if (val instanceof Number) return ((Number) val).longValue();
        return Long.parseLong(String.valueOf(val));
    }

    private Object get(String dottedKey) {
        String[] parts = dottedKey.split("\\.");
        Object curr = root;
        for (String p : parts) {
            if (!(curr instanceof Map)) return null;
            curr = ((Map<?, ?>) curr).get(p);
            if (curr == null) return null;
        }
        return curr;
    }
}


