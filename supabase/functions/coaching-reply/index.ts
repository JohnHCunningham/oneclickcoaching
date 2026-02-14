import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// HTML template for the reply form
function generateReplyFormHTML(coachingMessage: any, repName: string): string {
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Reply to Coaching - The Revenue Factory</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: linear-gradient(135deg, #0C1030, #1a2550); min-height: 100vh; padding: 20px; }
    .container { max-width: 700px; margin: 0 auto; background: #131a40; border-radius: 20px; overflow: hidden; box-shadow: 0 20px 60px rgba(0,0,0,0.4); }
    .header { background: linear-gradient(135deg, #10C3B0, #3DE0D2); padding: 30px; text-align: center; }
    .header h1 { color: white; margin: 0; font-size: 24px; }
    .header p { color: rgba(255,255,255,0.9); margin: 10px 0 0; }
    .content { padding: 30px; color: #F2F4F8; }
    .original-message { background: rgba(255,255,255,0.05); border-left: 4px solid #10C3B0; padding: 20px; border-radius: 0 10px 10px 0; margin-bottom: 25px; }
    .original-message h3 { color: #F4B03A; font-size: 14px; margin-bottom: 10px; }
    .original-message p { color: rgba(242,244,248,0.8); line-height: 1.7; white-space: pre-wrap; font-size: 14px; max-height: 200px; overflow-y: auto; }
    .form-group { margin-bottom: 20px; }
    label { display: block; color: #10C3B0; font-weight: 600; margin-bottom: 8px; }
    textarea { width: 100%; background: rgba(255,255,255,0.05); border: 1px solid rgba(255,255,255,0.1); border-radius: 10px; padding: 15px; color: #F2F4F8; font-size: 15px; font-family: inherit; resize: vertical; min-height: 150px; }
    textarea:focus { outline: none; border-color: #10C3B0; box-shadow: 0 0 0 3px rgba(16,195,176,0.2); }
    .btn { display: block; width: 100%; background: linear-gradient(135deg, #10C3B0, #3DE0D2); color: white; border: none; padding: 15px 30px; border-radius: 25px; font-size: 16px; font-weight: 700; cursor: pointer; transition: all 0.2s ease; }
    .btn:hover { transform: translateY(-2px); box-shadow: 0 10px 30px rgba(16,195,176,0.4); }
    .btn:disabled { opacity: 0.6; cursor: not-allowed; transform: none; }
    .success-message { display: none; background: linear-gradient(135deg, #10C3B0, #3DE0D2); padding: 30px; text-align: center; border-radius: 10px; margin-top: 20px; }
    .success-message h2 { color: white; margin-bottom: 10px; }
    .success-message p { color: rgba(255,255,255,0.9); }
    .error-message { display: none; background: #E64563; padding: 15px; border-radius: 10px; margin-top: 15px; color: white; text-align: center; }
    .footer { padding: 20px; text-align: center; color: rgba(242,244,248,0.5); font-size: 13px; border-top: 1px solid rgba(255,255,255,0.05); }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>The Revenue Factory</h1>
      <p>Reply to Your Manager's Coaching</p>
    </div>
    <div class="content">
      <div class="original-message">
        <h3>Original Coaching Message</h3>
        <p>${escapeHtml(coachingMessage.coaching_content)}</p>
      </div>

      <form id="reply-form">
        <input type="hidden" id="message-id" value="${coachingMessage.id}">

        <div class="form-group">
          <label for="reply">Your Response to ${coachingMessage.manager_email}</label>
          <textarea id="reply" name="reply" placeholder="Type your questions, feedback, or acknowledgment here...

Examples:
- Thanks for the feedback! I'll focus on this in my next calls.
- I have a question about the pain funnel technique...
- I tried this approach and here's what happened..." required></textarea>
        </div>

        <button type="submit" class="btn" id="submit-btn">Send Reply</button>
      </form>

      <div class="success-message" id="success-message">
        <h2>Reply Sent!</h2>
        <p>Your manager will see your response on their dashboard.</p>
      </div>

      <div class="error-message" id="error-message"></div>
    </div>
    <div class="footer">
      Powered by The Revenue Factory | AI Advantage Solutions
    </div>
  </div>

  <script>
    document.getElementById('reply-form').addEventListener('submit', async (e) => {
      e.preventDefault();

      const btn = document.getElementById('submit-btn');
      const reply = document.getElementById('reply').value;
      const messageId = document.getElementById('message-id').value;
      const errorEl = document.getElementById('error-message');
      const successEl = document.getElementById('success-message');
      const form = document.getElementById('reply-form');

      btn.disabled = true;
      btn.textContent = 'Sending...';
      errorEl.style.display = 'none';

      try {
        const response = await fetch(window.location.href, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ message_id: messageId, reply_text: reply })
        });

        const result = await response.json();

        if (result.success) {
          form.style.display = 'none';
          successEl.style.display = 'block';
        } else {
          throw new Error(result.error || 'Failed to send reply');
        }
      } catch (error) {
        errorEl.textContent = error.message;
        errorEl.style.display = 'block';
        btn.disabled = false;
        btn.textContent = 'Send Reply';
      }
    });
  </script>
</body>
</html>`;
}

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

// HTML for success page
function generateSuccessHTML(): string {
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Reply Sent - The Revenue Factory</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: linear-gradient(135deg, #0C1030, #1a2550); min-height: 100vh; display: flex; align-items: center; justify-content: center; }
    .container { background: #131a40; padding: 50px; border-radius: 20px; text-align: center; max-width: 500px; }
    h1 { color: #10C3B0; margin-bottom: 15px; }
    p { color: rgba(242,244,248,0.8); line-height: 1.6; }
    .icon { font-size: 60px; margin-bottom: 20px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="icon">✅</div>
    <h1>Reply Sent Successfully!</h1>
    <p>Your manager will see your response on their dashboard. You can close this window.</p>
  </div>
</body>
</html>`;
}

// HTML for error page
function generateErrorHTML(message: string): string {
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Error - The Revenue Factory</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: linear-gradient(135deg, #0C1030, #1a2550); min-height: 100vh; display: flex; align-items: center; justify-content: center; }
    .container { background: #131a40; padding: 50px; border-radius: 20px; text-align: center; max-width: 500px; }
    h1 { color: #E64563; margin-bottom: 15px; }
    p { color: rgba(242,244,248,0.8); line-height: 1.6; }
    .icon { font-size: 60px; margin-bottom: 20px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="icon">❌</div>
    <h1>Something Went Wrong</h1>
    <p>${escapeHtml(message)}</p>
  </div>
</body>
</html>`;
}

serve(async (req) => {
  const url = new URL(req.url);
  const token = url.searchParams.get("token");

  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // GET request - show reply form
  if (req.method === "GET") {
    if (!token) {
      return new Response(generateErrorHTML("Invalid or missing reply token"), {
        headers: { "Content-Type": "text/html" },
        status: 400,
      });
    }

    // Find coaching message by reply token
    const { data: message, error } = await supabase
      .from("Coaching_Messages")
      .select("*")
      .eq("reply_token", token)
      .single();

    if (error || !message) {
      return new Response(
        generateErrorHTML("This reply link has expired or is invalid. Please contact your manager."),
        { headers: { "Content-Type": "text/html" }, status: 404 }
      );
    }

    // Check if already replied
    if (message.rep_response) {
      return new Response(
        generateErrorHTML("You have already replied to this coaching message."),
        { headers: { "Content-Type": "text/html" }, status: 400 }
      );
    }

    // Mark as read if not already
    if (!message.read_at) {
      await supabase
        .from("Coaching_Messages")
        .update({ read_at: new Date().toISOString() })
        .eq("id", message.id);
    }

    // Get rep name from email
    const repName = message.rep_email.split("@")[0].replace(/[._]/g, " ");

    return new Response(generateReplyFormHTML(message, repName), {
      headers: { "Content-Type": "text/html" },
    });
  }

  // POST request - submit reply
  if (req.method === "POST") {
    try {
      const body = await req.json();
      const { message_id, reply_text } = body;

      if (!message_id || !reply_text) {
        return new Response(
          JSON.stringify({ success: false, error: "Missing message_id or reply_text" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Update the coaching message with the reply
      const { error: updateError } = await supabase
        .from("Coaching_Messages")
        .update({
          rep_response: reply_text,
          responded_at: new Date().toISOString(),
          status: "replied",
        })
        .eq("id", message_id);

      if (updateError) {
        console.error("Error saving reply:", updateError);
        return new Response(
          JSON.stringify({ success: false, error: "Failed to save reply" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      return new Response(
        JSON.stringify({ success: true, message: "Reply saved successfully" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    } catch (error) {
      console.error("Reply error:", error);
      return new Response(
        JSON.stringify({ success: false, error: error.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
  }

  return new Response("Method not allowed", { status: 405 });
});
