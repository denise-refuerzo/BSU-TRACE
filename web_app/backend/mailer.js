const nodemailer = require('nodemailer');
require('dotenv').config();

// Create the transporter engine using Gmail SMTP
const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS
    }
});

/**
 * Helper function to send password reset emails
 * @param {string} toEmail - The recipient's email address
 * @param {string} username - The user's username
 * @param {string} code - The 6-digit verification token
 */
const sendResetCodeEmail = async (toEmail, username, code) => {
    const mailOptions = {
        from: `"BSU-Trace System" <${process.env.EMAIL_USER}>`,
        to: toEmail,
        subject: 'Password Reset Verification Code',
        html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 8px;">
                <h2 style="color: #800000; text-align: center;">BSU-Trace Password Reset</h2>
                <p>Hello <strong>${username}</strong>,</p>
                <p>We received a request to reset your password for your university portal account.</p>
                <div style="background-color: #f9f9f9; padding: 15px; text-align: center; border-radius: 6px; margin: 20px 0;">
                    <span style="font-size: 24px; font-weight: bold; letter-spacing: 4px; color: #333;">${code}</span>
                </div>
                <p>This verification code is valid for <strong>10 minutes</strong>. If you did not request this, please ignore this email or contact ICT Support.</p>
                <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;" />
                <p style="font-size: 12px; color: #777; text-align: center;">© 2026 BSU Institutional Management. All Rights Reserved.</p>
            </div>
        `
    };

    try {
        await transporter.sendMail(mailOptions);
        console.log(`Password reset email successfully sent to: ${toEmail}`);
        return { success: true };
    } catch (error) {
        console.error('Nodemailer Error:', error);
        return { success: false, error: error.message };
    }
};

const sendTrackingAlertEmail = async (toEmail, fullName, documentTitle, currentStatus, bodyText) => {
    const mailOptions = {
        from: `"BSU-Trace System" <${process.env.EMAIL_USER}>`,
        to: toEmail,
        subject: `BSU-Trace Notification: Document Status Updated`,
        html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 8px;">
                <h2 style="color: #800000; text-align: center;">BSU-Trace Document Update</h2>
                <p>Hello <strong>${fullName}</strong>,</p>
                <p>There has been a change in your document tracking log pipeline sequence:</p>
                <div style="background-color: #f9f9f9; padding: 15px; border-left: 4px solid #800000; border-radius: 4px; margin: 20px 0;">
                    <p style="margin: 5px 0;"><strong>Document:</strong> ${documentTitle}</p>
                    <p style="margin: 5px 0;"><strong>Current Status:</strong> <span style="color: #800000; font-weight: bold;">${currentStatus}</span></p>
                </div>
                <p>${bodyText}</p>
                <p>Please check your university management system dashboard terminal for full historical verification routing logs.</p>
                <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;" />
                <p style="font-size: 12px; color: #777; text-align: center;">© 2026 BSU Institutional Management. All Rights Reserved.</p>
            </div>
        `
    };

    try {
        await transporter.sendMail(mailOptions);
        console.log(`✉️ Workflow tracking email successfully sent to: ${toEmail}`);
        return { success: true };
    } catch (error) {
        console.error('Nodemailer Workflow Error:', error);
        return { success: false, error: error.message };
    }
};

const sendSystemEmail = async (toEmail, subject, textBody) => {
    try {
      const mailOptions = {
        from: process.env.EMAIL_USER, // Your configured email address
        to: toEmail,
        subject: subject,
        text: textBody
      };
  
      await transporter.sendMail(mailOptions);
      return { success: true };
    } catch (error) {
      console.error('Error sending system email:', error);
      return { success: false, error };
    }
  };

// EXPORT BOTH SYSTEM HANDLERS AT THE BOTTOM
module.exports = { sendResetCodeEmail, sendTrackingAlertEmail, sendSystemEmail };