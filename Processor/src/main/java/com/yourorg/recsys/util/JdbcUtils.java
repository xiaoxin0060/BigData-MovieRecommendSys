package com.yourorg.recsys.util;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.util.Properties;

public class JdbcUtils {
    private final String url;
    private final String user;
    private final String password;

    public JdbcUtils(String host, int port, String database, String params, String user, String password) {
        String paramString = (params == null || params.isEmpty()) ? "" : ("?" + params);
        this.url = String.format("jdbc:mysql://%s:%d/%s%s", host, port, database, paramString);
        this.user = user;
        this.password = password;
    }

    public Connection getConnection() throws SQLException {
        Properties props = new Properties();
        props.setProperty("user", user);
        props.setProperty("password", password);
        return DriverManager.getConnection(url, props);
    }

    public static void quietClose(AutoCloseable c) {
        if (c != null) {
            try { c.close(); } catch (Exception ignored) {}
        }
    }

    public static void setParams(PreparedStatement ps, Object... params) throws SQLException {
        if (params == null) return;
        for (int i = 0; i < params.length; i++) {
            ps.setObject(i + 1, params[i]);
        }
    }
}


