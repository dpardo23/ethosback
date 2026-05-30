package com.ethoshub.config;

import jakarta.servlet.Filter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

import java.io.IOException;

@Component
@Order(1)
public class NoCacheFilter implements Filter {

    private static final String[] PUBLIC_PASSTHROUGH = {
            "/swagger-ui", "/v3/api-docs", "/api/ping"
    };

    @Override
    public void doFilter(ServletRequest req, ServletResponse res, FilterChain chain)
            throws IOException, ServletException {

        HttpServletRequest  request  = (HttpServletRequest)  req;
        HttpServletResponse response = (HttpServletResponse) res;

        if (!isPassthrough(request.getRequestURI())) {
            response.setHeader("Cache-Control", "no-cache, no-store, max-age=0, must-revalidate");
            response.setHeader("Pragma",        "no-cache");
            response.setHeader("Expires",       "0");
        }

        chain.doFilter(req, res);
    }

    private boolean isPassthrough(String uri) {
        for (String prefix : PUBLIC_PASSTHROUGH) {
            if (uri.startsWith(prefix)) return true;
        }
        return false;
    }
}
