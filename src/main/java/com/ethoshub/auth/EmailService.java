package com.ethoshub.auth;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import jakarta.mail.MessagingException;
import jakarta.mail.internet.MimeMessage;

@Service
class EmailService {

    private static final Logger log = LoggerFactory.getLogger(EmailService.class);

    private final JavaMailSender mailSender;
    private final String         fromAddress;
    private final String         fromName;

    EmailService(
            JavaMailSender mailSender,
            @Value("${spring.mail.from:noreply@ethoshub.com}") String fromAddress,
            @Value("${spring.mail.from-name:EthosHub}")        String fromName
    ) {
        this.mailSender  = mailSender;
        this.fromAddress = fromAddress;
        this.fromName    = fromName;
    }

    @Async
    void sendWelcomeEmail(String toEmail, String firstName) {
        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");

            helper.setFrom(fromAddress, fromName);
            helper.setTo(toEmail);
            helper.setSubject("¡Bienvenido a EthosHub, " + firstName + "!");
            helper.setText(buildWelcomeHtml(firstName, toEmail), true);

            mailSender.send(message);
            log.info("Welcome email sent to {}", toEmail);
        } catch (MessagingException | java.io.UnsupportedEncodingException ex) {
            log.warn("Failed to send welcome email to {}: {}", toEmail, ex.getMessage());
        }
    }

    private String buildWelcomeHtml(String firstName, String email) {
        return """
            <!DOCTYPE html>
            <html lang="es">
            <head>
              <meta charset="UTF-8"/>
              <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
              <title>Bienvenido a EthosHub</title>
            </head>
            <body style="margin:0;padding:0;background-color:#0a0a14;font-family:'Segoe UI',Arial,sans-serif;">
              <table width="100%%" cellpadding="0" cellspacing="0" style="background-color:#0a0a14;padding:40px 16px;">
                <tr>
                  <td align="center">
                    <table width="560" cellpadding="0" cellspacing="0"
                           style="max-width:560px;width:100%%;border-radius:20px;overflow:hidden;
                                  border:1px solid rgba(255,255,255,0.08);">

                      <!-- Header -->
                      <tr>
                        <td style="background:linear-gradient(135deg,#5b21b6 0%%,#7c3aed 50%%,#a855f7 100%%);
                                   padding:40px 40px 32px;text-align:center;">
                          <div style="display:inline-block;background:rgba(255,255,255,0.12);
                                      border-radius:16px;padding:12px 24px;margin-bottom:20px;">
                            <span style="font-size:22px;font-weight:800;color:#ffffff;letter-spacing:-0.5px;">
                              Ethos<span style="color:#e9d5ff;">Hub</span>
                            </span>
                          </div>
                          <h1 style="margin:0;font-size:26px;font-weight:700;color:#ffffff;line-height:1.3;">
                            ¡Bienvenido, %s!
                          </h1>
                          <p style="margin:12px 0 0;font-size:14px;color:rgba(255,255,255,0.75);">
                            Tu cuenta ha sido creada exitosamente
                          </p>
                        </td>
                      </tr>

                      <!-- Body -->
                      <tr>
                        <td style="background:#0e0e1c;padding:36px 40px;">
                          <p style="margin:0 0 20px;font-size:15px;color:rgba(255,255,255,0.75);line-height:1.65;">
                            Nos alegra tenerte en <strong style="color:#a78bfa;">EthosHub</strong>,
                            la plataforma que conecta el talento tech con oportunidades reales.
                          </p>

                          <!-- Steps -->
                          <table width="100%%" cellpadding="0" cellspacing="0" style="margin:24px 0;">
                            <tr>
                              <td style="background:rgba(124,58,237,0.08);border:1px solid rgba(124,58,237,0.18);
                                         border-radius:14px;padding:20px 24px;">
                                <p style="margin:0 0 12px;font-size:12px;font-weight:700;
                                          color:#a78bfa;text-transform:uppercase;letter-spacing:1px;">
                                  Próximos pasos
                                </p>
                                <table cellpadding="0" cellspacing="0">
                                  <tr>
                                    <td style="padding:6px 0;">
                                      <span style="color:#7c3aed;font-size:16px;margin-right:10px;">→</span>
                                      <span style="font-size:14px;color:rgba(255,255,255,0.80);">
                                        Completa tu perfil profesional
                                      </span>
                                    </td>
                                  </tr>
                                  <tr>
                                    <td style="padding:6px 0;">
                                      <span style="color:#7c3aed;font-size:16px;margin-right:10px;">→</span>
                                      <span style="font-size:14px;color:rgba(255,255,255,0.80);">
                                        Agrega tus habilidades y experiencia
                                      </span>
                                    </td>
                                  </tr>
                                  <tr>
                                    <td style="padding:6px 0;">
                                      <span style="color:#7c3aed;font-size:16px;margin-right:10px;">→</span>
                                      <span style="font-size:14px;color:rgba(255,255,255,0.80);">
                                        Conecta con la comunidad tech
                                      </span>
                                    </td>
                                  </tr>
                                </table>
                              </td>
                            </tr>
                          </table>

                          <!-- CTA -->
                          <table width="100%%" cellpadding="0" cellspacing="0" style="margin:28px 0;">
                            <tr>
                              <td align="center">
                                <a href="https://ethoshub.com/dashboard"
                                   style="display:inline-block;background:linear-gradient(135deg,#7c3aed,#a855f7);
                                          color:#ffffff;font-size:14px;font-weight:700;text-decoration:none;
                                          padding:14px 36px;border-radius:12px;
                                          box-shadow:0 4px 24px rgba(124,58,237,0.4);">
                                  Ir a mi perfil →
                                </a>
                              </td>
                            </tr>
                          </table>

                          <p style="margin:0;font-size:13px;color:rgba(255,255,255,0.35);text-align:center;">
                            Este correo fue enviado a %s.<br/>
                            Si no creaste esta cuenta, ignora este mensaje.
                          </p>
                        </td>
                      </tr>

                      <!-- Footer -->
                      <tr>
                        <td style="background:#07070f;padding:20px 40px;text-align:center;
                                   border-top:1px solid rgba(255,255,255,0.05);">
                          <p style="margin:0;font-size:12px;color:rgba(255,255,255,0.25);">
                            © 2026 EthosHub · Todos los derechos reservados
                          </p>
                        </td>
                      </tr>

                    </table>
                  </td>
                </tr>
              </table>
            </body>
            </html>
            """.formatted(firstName, email);
    }
}
