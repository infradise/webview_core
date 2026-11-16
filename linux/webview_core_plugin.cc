#include "include/webview_core/webview_core_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <webkit2/webkit2.h>

#include <cmath>
#include <cstdint>
#include <cstring>
#include <map>
#include <memory>
#include <set>
#include <string>
#include <vector>

namespace {

std::string EscapeJsonString(const std::string& input) {
  std::string out;
  out.reserve(input.size() + 2);
  out.push_back('"');
  for (size_t i = 0; i < input.size(); ++i) {
    const unsigned char c = static_cast<unsigned char>(input[i]);
    switch (c) {
      case '"':
        out += "\\\"";
        break;
      case '\\':
        out += "\\\\";
        break;
      case '\n':
        out += "\\n";
        break;
      case '\r':
        out += "\\r";
        break;
      case '\t':
        out += "\\t";
        break;
      default:
        if (c < 0x20) {
          char buf[8];
          snprintf(buf, sizeof(buf), "\\u%04x", static_cast<unsigned int>(c));
          out += buf;
        } else {
          out.push_back(static_cast<char>(c));
        }
        break;
    }
  }
  out.push_back('"');
  return out;
}

FlValue* LookupMapValue(FlValue* map, const char* key) {
  if (map == nullptr || fl_value_get_type(map) != FL_VALUE_TYPE_MAP) {
    return nullptr;
  }
  return fl_value_lookup_string(map, key);
}

bool GetIntArg(FlValue* map, const char* key, int64_t* out) {
  FlValue* val = LookupMapValue(map, key);
  if (val == nullptr || fl_value_get_type(val) != FL_VALUE_TYPE_INT) {
    return false;
  }
  *out = fl_value_get_int(val);
  return true;
}

bool GetBoolArg(FlValue* map, const char* key, bool default_val) {
  FlValue* val = LookupMapValue(map, key);
  if (val == nullptr || fl_value_get_type(val) != FL_VALUE_TYPE_BOOL) {
    return default_val;
  }
  return fl_value_get_bool(val) != FALSE;
}

std::string GetStringArg(FlValue* map, const char* key, bool* found = nullptr) {
  FlValue* val = LookupMapValue(map, key);
  if (val == nullptr || fl_value_get_type(val) != FL_VALUE_TYPE_STRING) {
    if (found != nullptr) {
      *found = false;
    }
    return std::string();
  }
  if (found != nullptr) {
    *found = true;
  }
  const char* raw = fl_value_get_string(val);
  return raw != nullptr ? std::string(raw) : std::string();
}

FlValue* JscValueToFlValue(JSCValue* value) {
  if (value == nullptr || jsc_value_is_null(value) ||
      jsc_value_is_undefined(value)) {
    return fl_value_new_null();
  }
  if (jsc_value_is_boolean(value)) {
    return fl_value_new_bool(jsc_value_to_boolean(value));
  }
  if (jsc_value_is_number(value)) {
    const double d = jsc_value_to_double(value);
    const double rounded = std::floor(d);
    if (std::isfinite(d) && d == rounded && d >= -9007199254740991.0 &&
        d <= 9007199254740991.0) {
      return fl_value_new_int(static_cast<int64_t>(d));
    }
    return fl_value_new_float(d);
  }
  if (jsc_value_is_string(value)) {
    gchar* str = jsc_value_to_string(value);
    FlValue* res = fl_value_new_string(str != nullptr ? str : "");
    g_free(str);
    return res;
  }
  gchar* json = jsc_value_to_json(value, 0);
  if (json != nullptr) {
    FlValue* res = fl_value_new_string(json);
    g_free(json);
    return res;
  }
  gchar* fallback = jsc_value_to_string(value);
  FlValue* res = fl_value_new_string(fallback != nullptr ? fallback : "");
  g_free(fallback);
  return res;
}

struct LinuxWebViewInstance;

struct PluginState {
  FlPluginRegistrar* registrar = nullptr;
  FlMethodChannel* channel = nullptr;
  GtkOverlay* overlay = nullptr;
  gulong child_pos_handler_id = 0;
  gulong overlay_destroy_id = 0;
  std::map<int64_t, std::unique_ptr<LinuxWebViewInstance>> instances;
};

struct ChannelCallbackData {
  PluginState* state = nullptr;
  int64_t controller_id = 0;
  std::string channel_name;
};

struct PendingPolicyData {
  WebKitPolicyDecision* decision = nullptr;
};

struct PendingJsCallData {
  FlMethodCall* call = nullptr;
  bool return_result = false;
  bool is_scroll_pos = false;
};

struct LinuxWebViewInstance {
  PluginState* state = nullptr;
  int64_t controller_id = 0;
  GtkWidget* clip_container = nullptr;
  GtkWidget* webview = nullptr;
  WebKitUserContentManager* ucm = nullptr;
  bool visible = false;
  int x = 0;
  int y = 0;
  int width = 0;
  int height = 0;
  int full_x = 0;
  int full_y = 0;
  int full_width = 0;
  int full_height = 0;
  bool has_navigation_decision = false;
  bool zoom_enabled = true;
  std::string default_user_agent;
  std::map<std::string, gulong> channel_signal_ids;
  std::vector<std::unique_ptr<ChannelCallbackData>> channel_datas;
  gulong load_changed_id = 0;
  gulong load_failed_id = 0;
  gulong notify_uri_id = 0;
  gulong notify_progress_id = 0;
  gulong decide_policy_id = 0;
  gulong webview_destroy_id = 0;
  gulong clip_destroy_id = 0;
  bool destroyed = false;

  ~LinuxWebViewInstance() { Destroy(); }

  void Destroy() {
    if (destroyed) {
      return;
    }
    destroyed = true;
    if (ucm != nullptr) {
      for (std::map<std::string, gulong>::iterator it =
               channel_signal_ids.begin();
           it != channel_signal_ids.end(); ++it) {
        if (it->second != 0) {
          g_signal_handler_disconnect(ucm, it->second);
        }
        webkit_user_content_manager_unregister_script_message_handler(
            ucm, it->first.c_str());
      }
      channel_signal_ids.clear();
      webkit_user_content_manager_remove_all_scripts(ucm);
      g_clear_object(&ucm);
    }
    if (webview != nullptr) {
      if (load_changed_id != 0) {
        g_signal_handler_disconnect(webview, load_changed_id);
        load_changed_id = 0;
      }
      if (load_failed_id != 0) {
        g_signal_handler_disconnect(webview, load_failed_id);
        load_failed_id = 0;
      }
      if (notify_uri_id != 0) {
        g_signal_handler_disconnect(webview, notify_uri_id);
        notify_uri_id = 0;
      }
      if (notify_progress_id != 0) {
        g_signal_handler_disconnect(webview, notify_progress_id);
        notify_progress_id = 0;
      }
      if (decide_policy_id != 0) {
        g_signal_handler_disconnect(webview, decide_policy_id);
        decide_policy_id = 0;
      }
      if (webview_destroy_id != 0) {
        g_signal_handler_disconnect(webview, webview_destroy_id);
        webview_destroy_id = 0;
      }
      webkit_web_view_stop_loading(WEBKIT_WEB_VIEW(webview));
      gtk_widget_hide(webview);
      if (clip_container == nullptr) {
        GtkWidget* parent = gtk_widget_get_parent(webview);
        if (parent != nullptr) {
          gtk_container_remove(GTK_CONTAINER(parent), webview);
        } else {
          gtk_widget_destroy(webview);
        }
      }
      webview = nullptr;
    }
    if (clip_container != nullptr) {
      if (clip_destroy_id != 0) {
        g_signal_handler_disconnect(clip_container, clip_destroy_id);
        clip_destroy_id = 0;
      }
      gtk_widget_hide(clip_container);
      GtkWidget* parent = gtk_widget_get_parent(clip_container);
      if (parent != nullptr) {
        gtk_container_remove(GTK_CONTAINER(parent), clip_container);
      } else {
        gtk_widget_destroy(clip_container);
      }
      clip_container = nullptr;
    }
    channel_datas.clear();
  }
};

void OnWebViewDestroyed(GtkWidget* /*widget*/, gpointer user_data) {
  LinuxWebViewInstance* inst = static_cast<LinuxWebViewInstance*>(user_data);
  if (inst == nullptr) {
    return;
  }
  inst->load_changed_id = 0;
  inst->load_failed_id = 0;
  inst->notify_uri_id = 0;
  inst->notify_progress_id = 0;
  inst->decide_policy_id = 0;
  inst->webview_destroy_id = 0;
  inst->webview = nullptr;
}

void OnClipContainerDestroyed(GtkWidget* /*widget*/, gpointer user_data) {
  LinuxWebViewInstance* inst = static_cast<LinuxWebViewInstance*>(user_data);
  if (inst == nullptr) {
    return;
  }
  inst->clip_destroy_id = 0;
  inst->clip_container = nullptr;
}

void OnOverlayDestroyed(GtkWidget* /*widget*/, gpointer user_data) {
  PluginState* state = static_cast<PluginState*>(user_data);
  if (state == nullptr) {
    return;
  }
  state->child_pos_handler_id = 0;
  state->overlay_destroy_id = 0;
  state->overlay = nullptr;
}

void SendChannelEvent(PluginState* state, const char* method, FlValue* args) {
  if (state == nullptr || state->channel == nullptr) {
    if (args != nullptr) {
      fl_value_unref(args);
    }
    return;
  }
  fl_method_channel_invoke_method(state->channel, method, args, nullptr,
                                  nullptr, nullptr);
  if (args != nullptr) {
    fl_value_unref(args);
  }
}

gboolean OnOverlayGetChildPosition(GtkOverlay* /*overlay*/,
                                   GtkWidget* widget,
                                   GdkRectangle* allocation,
                                   gpointer user_data) {
  PluginState* state = static_cast<PluginState*>(user_data);
  if (state == nullptr) {
    return FALSE;
  }
  for (std::map<int64_t, std::unique_ptr<LinuxWebViewInstance>>::iterator it =
           state->instances.begin();
       it != state->instances.end(); ++it) {
    LinuxWebViewInstance* inst = it->second.get();
    if (inst != nullptr && inst->clip_container == widget) {
      allocation->x = inst->x;
      allocation->y = inst->y;
      allocation->width = inst->width > 0 ? inst->width : 1;
      allocation->height = inst->height > 0 ? inst->height : 1;
      return TRUE;
    }
  }
  return FALSE;
}

GtkOverlay* EnsureOverlay(PluginState* state) {
  if (state == nullptr || state->registrar == nullptr) {
    return nullptr;
  }
  if (state->overlay != nullptr) {
    return state->overlay;
  }
  FlView* fl_view = fl_plugin_registrar_get_view(state->registrar);
  if (fl_view == nullptr) {
    return nullptr;
  }
  GtkWidget* view_widget = GTK_WIDGET(fl_view);
  GtkWidget* parent = gtk_widget_get_parent(view_widget);
  if (parent == nullptr) {
    return nullptr;
  }

  if (GTK_IS_OVERLAY(parent)) {
    state->overlay = GTK_OVERLAY(parent);
  } else {
    GtkWidget* overlay_widget = gtk_overlay_new();
    gtk_widget_show(overlay_widget);
    g_object_ref(view_widget);
    gtk_container_remove(GTK_CONTAINER(parent), view_widget);
    gtk_container_add(GTK_CONTAINER(overlay_widget), view_widget);
    gtk_container_add(GTK_CONTAINER(parent), overlay_widget);
    g_object_unref(view_widget);
    state->overlay = GTK_OVERLAY(overlay_widget);
  }

  state->child_pos_handler_id = g_signal_connect(
      state->overlay, "get-child-position",
      G_CALLBACK(OnOverlayGetChildPosition), state);
  state->overlay_destroy_id = g_signal_connect(
      state->overlay, "destroy", G_CALLBACK(OnOverlayDestroyed), state);
  return state->overlay;
}

void RebuildUserScripts(LinuxWebViewInstance* inst) {
  if (inst == nullptr || inst->ucm == nullptr) {
    return;
  }
  webkit_user_content_manager_remove_all_scripts(inst->ucm);
  if (!inst->zoom_enabled) {
    const char* no_zoom_src =
        "window.addEventListener('wheel',function(e){"
        "if(e.ctrlKey){e.preventDefault();}},{passive:false});"
        "window.addEventListener('keydown',function(e){"
        "if((e.ctrlKey||e.metaKey)&&(e.key==='+'||e.key==='-'||e.key==='='||"
        "e.key==='0')){e.preventDefault();}},false);";
    WebKitUserScript* nz_script = webkit_user_script_new(
        no_zoom_src, WEBKIT_USER_CONTENT_INJECT_ALL_FRAMES,
        WEBKIT_USER_SCRIPT_INJECT_AT_DOCUMENT_START, nullptr, nullptr);
    webkit_user_content_manager_add_script(inst->ucm, nz_script);
    webkit_user_script_unref(nz_script);
  }
  for (std::map<std::string, gulong>::iterator it =
           inst->channel_signal_ids.begin();
       it != inst->channel_signal_ids.end(); ++it) {
    const std::string quoted = EscapeJsonString(it->first);
    const std::string script_src =
        "window[" + quoted + "]={postMessage:function(m){"
        "window.webkit.messageHandlers[" +
        quoted + "].postMessage(String(m));}};";
    WebKitUserScript* script = webkit_user_script_new(
        script_src.c_str(), WEBKIT_USER_CONTENT_INJECT_ALL_FRAMES,
        WEBKIT_USER_SCRIPT_INJECT_AT_DOCUMENT_START, nullptr, nullptr);
    webkit_user_content_manager_add_script(inst->ucm, script);
    webkit_user_script_unref(script);
  }
}

// Note: In webkit2gtk-4.1 (GTK3 ABI, !ENABLE(2022_GLIB_API)), the
// "script-message-received" signal always passes WebKitJavascriptResult* and
// register/unregister_script_message_handler always take 2 arguments across
// all 2.36..2.48+ releases (the 3-arg signature is exclusive to webkitgtk-6.0).
void OnScriptMessageReceived(WebKitUserContentManager* /*manager*/,
                             WebKitJavascriptResult* js_result,
                             gpointer user_data) {
  ChannelCallbackData* cb = static_cast<ChannelCallbackData*>(user_data);
  if (cb == nullptr || cb->state == nullptr) {
    return;
  }
  JSCValue* js_value =
      js_result != nullptr ? webkit_javascript_result_get_js_value(js_result)
                           : nullptr;
  gchar* msg = js_value != nullptr ? jsc_value_to_string(js_value) : nullptr;
  FlValue* map = fl_value_new_map();
  fl_value_set_string_take(map, "controllerId",
                           fl_value_new_int(cb->controller_id));
  fl_value_set_string_take(map, "channel",
                           fl_value_new_string(cb->channel_name.c_str()));
  fl_value_set_string_take(map, "message",
                           fl_value_new_string(msg != nullptr ? msg : ""));
  g_free(msg);
  SendChannelEvent(cb->state, "onJavaScriptMessage", map);
}

void AddJsChannel(LinuxWebViewInstance* inst, const std::string& name) {
  if (inst == nullptr || inst->ucm == nullptr || name.empty()) {
    return;
  }
  if (inst->channel_signal_ids.find(name) != inst->channel_signal_ids.end()) {
    return;
  }
  std::unique_ptr<ChannelCallbackData> cb(new ChannelCallbackData());
  cb->state = inst->state;
  cb->controller_id = inst->controller_id;
  cb->channel_name = name;
  ChannelCallbackData* raw_cb = cb.get();
  inst->channel_datas.push_back(std::move(cb));

  const std::string detail = "script-message-received::" + name;
  const gulong sig_id = g_signal_connect(
      inst->ucm, detail.c_str(), G_CALLBACK(OnScriptMessageReceived), raw_cb);
  webkit_user_content_manager_register_script_message_handler(inst->ucm,
                                                              name.c_str());
  inst->channel_signal_ids[name] = sig_id;
  RebuildUserScripts(inst);
}

void RemoveJsChannel(LinuxWebViewInstance* inst, const std::string& name) {
  if (inst == nullptr || inst->ucm == nullptr) {
    return;
  }
  std::map<std::string, gulong>::iterator it =
      inst->channel_signal_ids.find(name);
  if (it == inst->channel_signal_ids.end()) {
    return;
  }
  if (it->second != 0) {
    g_signal_handler_disconnect(inst->ucm, it->second);
  }
  webkit_user_content_manager_unregister_script_message_handler(inst->ucm,
                                                                name.c_str());
  inst->channel_signal_ids.erase(it);
  RebuildUserScripts(inst);
}

void ApplyBackgroundColor(LinuxWebViewInstance* inst, uint32_t argb) {
  if (inst == nullptr || inst->webview == nullptr) {
    return;
  }
  GdkRGBA rgba;
  rgba.alpha = static_cast<double>((argb >> 24) & 0xFF) / 255.0;
  rgba.red = static_cast<double>((argb >> 16) & 0xFF) / 255.0;
  rgba.green = static_cast<double>((argb >> 8) & 0xFF) / 255.0;
  rgba.blue = static_cast<double>(argb & 0xFF) / 255.0;
  webkit_web_view_set_background_color(WEBKIT_WEB_VIEW(inst->webview), &rgba);
}

void OnLoadChanged(WebKitWebView* web_view,
                   WebKitLoadEvent load_event,
                   gpointer user_data) {
  LinuxWebViewInstance* inst = static_cast<LinuxWebViewInstance*>(user_data);
  if (inst == nullptr || inst->destroyed) {
    return;
  }
  const gchar* uri = webkit_web_view_get_uri(web_view);
  const char* safe_uri = uri != nullptr ? uri : "";
  if (load_event == WEBKIT_LOAD_STARTED) {
    FlValue* map = fl_value_new_map();
    fl_value_set_string_take(map, "controllerId",
                             fl_value_new_int(inst->controller_id));
    fl_value_set_string_take(map, "url", fl_value_new_string(safe_uri));
    SendChannelEvent(inst->state, "onPageStarted", map);
  } else if (load_event == WEBKIT_LOAD_FINISHED) {
    FlValue* map = fl_value_new_map();
    fl_value_set_string_take(map, "controllerId",
                             fl_value_new_int(inst->controller_id));
    fl_value_set_string_take(map, "url", fl_value_new_string(safe_uri));
    SendChannelEvent(inst->state, "onPageFinished", map);
  }
}

gboolean OnLoadFailed(WebKitWebView* /*web_view*/,
                      WebKitLoadEvent /*load_event*/,
                      gchar* failing_uri,
                      GError* error,
                      gpointer user_data) {
  LinuxWebViewInstance* inst = static_cast<LinuxWebViewInstance*>(user_data);
  if (inst == nullptr || inst->destroyed || error == nullptr) {
    return FALSE;
  }
  if (g_error_matches(error, WEBKIT_NETWORK_ERROR,
                      WEBKIT_NETWORK_ERROR_CANCELLED)) {
    return FALSE;
  }
  FlValue* map = fl_value_new_map();
  fl_value_set_string_take(map, "controllerId",
                           fl_value_new_int(inst->controller_id));
  fl_value_set_string_take(map, "errorCode", fl_value_new_int(error->code));
  fl_value_set_string_take(
      map, "description",
      fl_value_new_string(error->message != nullptr ? error->message
                                                    : "Unknown error"));
  fl_value_set_string_take(map, "errorType", fl_value_new_string("unknown"));
  fl_value_set_string_take(map, "isForMainFrame", fl_value_new_bool(TRUE));
  fl_value_set_string_take(
      map, "url",
      failing_uri != nullptr ? fl_value_new_string(failing_uri)
                             : fl_value_new_null());
  SendChannelEvent(inst->state, "onWebResourceError", map);
  return FALSE;
}

void OnNotifyUri(GObject* object, GParamSpec* /*pspec*/, gpointer user_data) {
  LinuxWebViewInstance* inst = static_cast<LinuxWebViewInstance*>(user_data);
  if (inst == nullptr || inst->destroyed) {
    return;
  }
  const gchar* uri = webkit_web_view_get_uri(WEBKIT_WEB_VIEW(object));
  FlValue* map = fl_value_new_map();
  fl_value_set_string_take(map, "controllerId",
                           fl_value_new_int(inst->controller_id));
  fl_value_set_string_take(map, "url",
                           uri != nullptr ? fl_value_new_string(uri)
                                          : fl_value_new_null());
  SendChannelEvent(inst->state, "onUrlChange", map);
}

void OnNotifyProgress(GObject* object,
                      GParamSpec* /*pspec*/,
                      gpointer user_data) {
  LinuxWebViewInstance* inst = static_cast<LinuxWebViewInstance*>(user_data);
  if (inst == nullptr || inst->destroyed) {
    return;
  }
  const double progress =
      webkit_web_view_get_estimated_load_progress(WEBKIT_WEB_VIEW(object));
  int64_t pct = static_cast<int64_t>(std::round(progress * 100.0));
  if (pct < 0) {
    pct = 0;
  } else if (pct > 100) {
    pct = 100;
  }
  FlValue* map = fl_value_new_map();
  fl_value_set_string_take(map, "controllerId",
                           fl_value_new_int(inst->controller_id));
  fl_value_set_string_take(map, "progress", fl_value_new_int(pct));
  SendChannelEvent(inst->state, "onProgress", map);
}

void OnNavigationDecisionReply(GObject* source_object,
                               GAsyncResult* res,
                               gpointer user_data) {
  std::unique_ptr<PendingPolicyData> pending(
      static_cast<PendingPolicyData*>(user_data));
  bool allow = true;
  GError* error = nullptr;
  FlMethodResponse* response = fl_method_channel_invoke_method_finish(
      FL_METHOD_CHANNEL(source_object), res, &error);
  if (response != nullptr) {
    FlValue* result = fl_method_response_get_result(response, nullptr);
    if (result != nullptr && fl_value_get_type(result) == FL_VALUE_TYPE_BOOL) {
      allow = fl_value_get_bool(result) != FALSE;
    }
    g_object_unref(response);
  }
  if (error != nullptr) {
    g_error_free(error);
  }
  if (pending != nullptr && pending->decision != nullptr) {
    if (allow) {
      webkit_policy_decision_use(pending->decision);
    } else {
      webkit_policy_decision_ignore(pending->decision);
    }
    g_object_unref(pending->decision);
  }
}

gboolean OnDecidePolicy(WebKitWebView* /*web_view*/,
                        WebKitPolicyDecision* decision,
                        WebKitPolicyDecisionType decision_type,
                        gpointer user_data) {
  LinuxWebViewInstance* inst = static_cast<LinuxWebViewInstance*>(user_data);
  if (inst == nullptr || inst->destroyed || !inst->has_navigation_decision) {
    return FALSE;
  }
  if (decision_type != WEBKIT_POLICY_DECISION_TYPE_NAVIGATION_ACTION &&
      decision_type != WEBKIT_POLICY_DECISION_TYPE_NEW_WINDOW_ACTION) {
    return FALSE;
  }
  WebKitNavigationPolicyDecision* nav_decision =
      WEBKIT_NAVIGATION_POLICY_DECISION(decision);
  WebKitNavigationAction* action =
      webkit_navigation_policy_decision_get_navigation_action(nav_decision);
  WebKitURIRequest* req =
      action != nullptr ? webkit_navigation_action_get_request(action)
                        : nullptr;
  const gchar* uri = req != nullptr ? webkit_uri_request_get_uri(req) : nullptr;
  if (uri == nullptr || std::strcmp(uri, "about:blank") == 0) {
    return FALSE;
  }

  const bool is_main_frame =
      decision_type != WEBKIT_POLICY_DECISION_TYPE_NEW_WINDOW_ACTION;
  FlValue* map = fl_value_new_map();
  fl_value_set_string_take(map, "controllerId",
                           fl_value_new_int(inst->controller_id));
  fl_value_set_string_take(map, "url", fl_value_new_string(uri));
  fl_value_set_string_take(map, "isMainFrame",
                           fl_value_new_bool(is_main_frame ? TRUE : FALSE));

  PendingPolicyData* pending = new PendingPolicyData();
  pending->decision = WEBKIT_POLICY_DECISION(g_object_ref(decision));
  fl_method_channel_invoke_method(inst->state->channel, "onNavigationRequest",
                                  map, nullptr, OnNavigationDecisionReply,
                                  pending);
  fl_value_unref(map);
  return TRUE;
}

void LoadRequestOnWebView(LinuxWebViewInstance* inst,
                          const std::string& url,
                          const std::string& method,
                          FlValue* headers_val,
                          FlValue* body_val) {
  if (inst == nullptr || inst->webview == nullptr) {
    return;
  }
  std::string upper_method;
  upper_method.reserve(method.size());
  for (size_t i = 0; i < method.size(); ++i) {
    const unsigned char c = static_cast<unsigned char>(method[i]);
    upper_method.push_back(
        static_cast<char>((c >= 'a' && c <= 'z') ? (c - 'a' + 'A') : c));
  }

  if (upper_method.empty() || upper_method == "GET" || upper_method == "HEAD") {
    WebKitURIRequest* request = webkit_uri_request_new(url.c_str());
    if (headers_val != nullptr &&
        fl_value_get_type(headers_val) == FL_VALUE_TYPE_MAP) {
      SoupMessageHeaders* soup_headers =
          webkit_uri_request_get_http_headers(request);
      if (soup_headers != nullptr) {
        const size_t count = fl_value_get_length(headers_val);
        for (size_t i = 0; i < count; ++i) {
          FlValue* k = fl_value_get_map_key(headers_val, i);
          FlValue* v = fl_value_get_map_value(headers_val, i);
          if (k != nullptr && v != nullptr &&
              fl_value_get_type(k) == FL_VALUE_TYPE_STRING &&
              fl_value_get_type(v) == FL_VALUE_TYPE_STRING) {
            soup_message_headers_replace(soup_headers, fl_value_get_string(k),
                                         fl_value_get_string(v));
          }
        }
      }
    }
    webkit_web_view_load_request(WEBKIT_WEB_VIEW(inst->webview), request);
    g_object_unref(request);
    return;
  }

  // WebKitURIRequest in webkit2gtk-4.1 does not expose a setter for non-GET
  // HTTP methods; execute non-GET navigations via same-origin fetch() with
  // base_uri set to the target URL.
  std::string headers_json = "{";
  if (headers_val != nullptr &&
      fl_value_get_type(headers_val) == FL_VALUE_TYPE_MAP) {
    const size_t count = fl_value_get_length(headers_val);
    bool first = true;
    for (size_t i = 0; i < count; ++i) {
      FlValue* k = fl_value_get_map_key(headers_val, i);
      FlValue* v = fl_value_get_map_value(headers_val, i);
      if (k != nullptr && v != nullptr &&
          fl_value_get_type(k) == FL_VALUE_TYPE_STRING &&
          fl_value_get_type(v) == FL_VALUE_TYPE_STRING) {
        if (!first) {
          headers_json += ",";
        }
        first = false;
        headers_json += EscapeJsonString(fl_value_get_string(k)) + ":" +
                        EscapeJsonString(fl_value_get_string(v));
      }
    }
  }
  headers_json += "}";

  std::string body_expr = "undefined";
  if (body_val != nullptr &&
      fl_value_get_type(body_val) == FL_VALUE_TYPE_UINT8_LIST) {
    const size_t len = fl_value_get_length(body_val);
    const uint8_t* bytes = fl_value_get_uint8_list(body_val);
    if (bytes != nullptr && len > 0) {
      body_expr = "new Uint8Array([";
      for (size_t i = 0; i < len; ++i) {
        if (i > 0) {
          body_expr += ",";
        }
        char num[8];
        snprintf(num, sizeof(num), "%u", static_cast<unsigned int>(bytes[i]));
        body_expr += num;
      }
      body_expr += "])";
    }
  }

  const std::string bootstrap_html =
      "<!DOCTYPE html><html><head><meta charset=\"utf-8\"></head><body><script>"
      "fetch(" +
      EscapeJsonString(url) + ",{method:" + EscapeJsonString(upper_method) +
      ",headers:" + headers_json + ",body:" + body_expr +
      "}).then(function(r){return r.text();}).then(function(t){"
      "document.open();document.write(t);document.close();});"
      "</script></body></html>";
  webkit_web_view_load_html(WEBKIT_WEB_VIEW(inst->webview),
                            bootstrap_html.c_str(), url.c_str());
}

void OnClearCookiesFinished(GObject* source_object,
                            GAsyncResult* res,
                            gpointer user_data) {
  FlMethodCall* call = FL_METHOD_CALL(user_data);
  GError* error = nullptr;
  const gboolean ok = webkit_website_data_manager_clear_finish(
      WEBKIT_WEBSITE_DATA_MANAGER(source_object), res, &error);
  if (error != nullptr) {
    g_error_free(error);
  }
  FlValue* val = fl_value_new_bool(ok);
  fl_method_call_respond_success(call, val, nullptr);
  fl_value_unref(val);
  g_object_unref(call);
}

void OnAddCookieFinished(GObject* source_object,
                         GAsyncResult* res,
                         gpointer user_data) {
  FlMethodCall* call = FL_METHOD_CALL(user_data);
  GError* error = nullptr;
  webkit_cookie_manager_add_cookie_finish(WEBKIT_COOKIE_MANAGER(source_object),
                                          res, &error);
  if (error != nullptr) {
    g_error_free(error);
  }
  fl_method_call_respond_success(call, nullptr, nullptr);
  g_object_unref(call);
}

#if WEBKIT_CHECK_VERSION(2, 40, 0)
void OnJsEvaluated(GObject* source_object,
                   GAsyncResult* res,
                   gpointer user_data) {
  std::unique_ptr<PendingJsCallData> pending(
      static_cast<PendingJsCallData*>(user_data));
  GError* error = nullptr;
  JSCValue* value = webkit_web_view_evaluate_javascript_finish(
      WEBKIT_WEB_VIEW(source_object), res, &error);
  if (error != nullptr) {
    if (pending->return_result) {
      fl_method_call_respond_error(
          pending->call, "JS_ERROR",
          error->message != nullptr ? error->message : "JavaScript error",
          nullptr, nullptr);
    } else if (pending->is_scroll_pos) {
      FlValue* pos = fl_value_new_map();
      fl_value_set_string_take(pos, "x", fl_value_new_float(0.0));
      fl_value_set_string_take(pos, "y", fl_value_new_float(0.0));
      fl_method_call_respond_success(pending->call, pos, nullptr);
      fl_value_unref(pos);
    } else {
      fl_method_call_respond_success(pending->call, nullptr, nullptr);
    }
    g_error_free(error);
    g_object_unref(pending->call);
    return;
  }

  if (pending->is_scroll_pos) {
    double x = 0.0;
    double y = 0.0;
    if (value != nullptr && jsc_value_is_object(value)) {
      JSCValue* xv = jsc_value_object_get_property_at_index(value, 0);
      JSCValue* yv = jsc_value_object_get_property_at_index(value, 1);
      if (xv != nullptr) {
        x = jsc_value_to_double(xv);
        g_object_unref(xv);
      }
      if (yv != nullptr) {
        y = jsc_value_to_double(yv);
        g_object_unref(yv);
      }
    }
    FlValue* pos = fl_value_new_map();
    fl_value_set_string_take(pos, "x", fl_value_new_float(x));
    fl_value_set_string_take(pos, "y", fl_value_new_float(y));
    fl_method_call_respond_success(pending->call, pos, nullptr);
    fl_value_unref(pos);
  } else if (pending->return_result) {
    FlValue* out = JscValueToFlValue(value);
    fl_method_call_respond_success(pending->call, out, nullptr);
    fl_value_unref(out);
  } else {
    fl_method_call_respond_success(pending->call, nullptr, nullptr);
  }
  if (value != nullptr) {
    g_object_unref(value);
  }
  g_object_unref(pending->call);
}
#else
void OnJsEvaluated(GObject* source_object,
                   GAsyncResult* res,
                   gpointer user_data) {
  std::unique_ptr<PendingJsCallData> pending(
      static_cast<PendingJsCallData*>(user_data));
  GError* error = nullptr;
  WebKitJavascriptResult* js_res = webkit_web_view_run_javascript_finish(
      WEBKIT_WEB_VIEW(source_object), res, &error);
  if (error != nullptr) {
    if (pending->return_result) {
      fl_method_call_respond_error(
          pending->call, "JS_ERROR",
          error->message != nullptr ? error->message : "JavaScript error",
          nullptr, nullptr);
    } else if (pending->is_scroll_pos) {
      FlValue* pos = fl_value_new_map();
      fl_value_set_string_take(pos, "x", fl_value_new_float(0.0));
      fl_value_set_string_take(pos, "y", fl_value_new_float(0.0));
      fl_method_call_respond_success(pending->call, pos, nullptr);
      fl_value_unref(pos);
    } else {
      fl_method_call_respond_success(pending->call, nullptr, nullptr);
    }
    g_error_free(error);
    g_object_unref(pending->call);
    return;
  }

  JSCValue* value =
      js_res != nullptr ? webkit_javascript_result_get_js_value(js_res)
                        : nullptr;
  if (pending->is_scroll_pos) {
    double x = 0.0;
    double y = 0.0;
    if (value != nullptr && jsc_value_is_object(value)) {
      JSCValue* xv = jsc_value_object_get_property_at_index(value, 0);
      JSCValue* yv = jsc_value_object_get_property_at_index(value, 1);
      if (xv != nullptr) {
        x = jsc_value_to_double(xv);
        g_object_unref(xv);
      }
      if (yv != nullptr) {
        y = jsc_value_to_double(yv);
        g_object_unref(yv);
      }
    }
    FlValue* pos = fl_value_new_map();
    fl_value_set_string_take(pos, "x", fl_value_new_float(x));
    fl_value_set_string_take(pos, "y", fl_value_new_float(y));
    fl_method_call_respond_success(pending->call, pos, nullptr);
    fl_value_unref(pos);
  } else if (pending->return_result) {
    FlValue* out = JscValueToFlValue(value);
    fl_method_call_respond_success(pending->call, out, nullptr);
    fl_value_unref(out);
  } else {
    fl_method_call_respond_success(pending->call, nullptr, nullptr);
  }
  if (js_res != nullptr) {
    webkit_javascript_result_unref(js_res);
  }
  g_object_unref(pending->call);
}
#endif

void EvaluateScriptAsync(LinuxWebViewInstance* inst,
                         const std::string& script,
                         FlMethodCall* call,
                         bool return_result,
                         bool is_scroll_pos) {
  if (inst == nullptr || inst->webview == nullptr) {
    if (is_scroll_pos) {
      FlValue* pos = fl_value_new_map();
      fl_value_set_string_take(pos, "x", fl_value_new_float(0.0));
      fl_value_set_string_take(pos, "y", fl_value_new_float(0.0));
      fl_method_call_respond_success(call, pos, nullptr);
      fl_value_unref(pos);
    } else {
      fl_method_call_respond_success(call, nullptr, nullptr);
    }
    return;
  }
  PendingJsCallData* pending = new PendingJsCallData();
  pending->call = FL_METHOD_CALL(g_object_ref(call));
  pending->return_result = return_result;
  pending->is_scroll_pos = is_scroll_pos;
#if WEBKIT_CHECK_VERSION(2, 40, 0)
  webkit_web_view_evaluate_javascript(
      WEBKIT_WEB_VIEW(inst->webview), script.c_str(),
      static_cast<gssize>(script.size()), nullptr, nullptr, nullptr,
      OnJsEvaluated, pending);
#else
  webkit_web_view_run_javascript(WEBKIT_WEB_VIEW(inst->webview), script.c_str(),
                                 nullptr, OnJsEvaluated, pending);
#endif
}

LinuxWebViewInstance* CreateInstance(PluginState* state,
                                     int64_t controller_id,
                                     FlValue* args) {
  state->instances.erase(controller_id);

  std::unique_ptr<LinuxWebViewInstance> inst(new LinuxWebViewInstance());
  inst->state = state;
  inst->controller_id = controller_id;
  inst->ucm = webkit_user_content_manager_new();
  inst->webview = webkit_web_view_new_with_user_content_manager(inst->ucm);
  inst->clip_container = gtk_layout_new(nullptr, nullptr);
  gtk_layout_put(GTK_LAYOUT(inst->clip_container), inst->webview, 0, 0);
  gtk_widget_show(inst->webview);

  WebKitSettings* settings =
      webkit_web_view_get_settings(WEBKIT_WEB_VIEW(inst->webview));
  const char* default_ua = webkit_settings_get_user_agent(settings);
  inst->default_user_agent = default_ua != nullptr ? default_ua : "";

  const bool js_enabled = GetBoolArg(args, "javaScriptEnabled", true);
  g_object_set(G_OBJECT(settings), "enable-javascript",
               js_enabled ? TRUE : FALSE, nullptr);

  inst->zoom_enabled = GetBoolArg(args, "zoomEnabled", true);
  inst->has_navigation_decision =
      GetBoolArg(args, "hasNavigationDecision", false);

  bool has_ua = false;
  const std::string custom_ua = GetStringArg(args, "userAgent", &has_ua);
  if (has_ua && !custom_ua.empty()) {
    webkit_settings_set_user_agent(settings, custom_ua.c_str());
  }

  int64_t bg_raw = 0;
  if (GetIntArg(args, "backgroundColor", &bg_raw)) {
    ApplyBackgroundColor(inst.get(), static_cast<uint32_t>(bg_raw));
  } else {
    ApplyBackgroundColor(inst.get(), 0);
  }

  FlValue* channels = LookupMapValue(args, "channelNames");
  if (channels != nullptr &&
      fl_value_get_type(channels) == FL_VALUE_TYPE_LIST) {
    const size_t n = fl_value_get_length(channels);
    for (size_t i = 0; i < n; ++i) {
      FlValue* item = fl_value_get_list_value(channels, i);
      if (item != nullptr && fl_value_get_type(item) == FL_VALUE_TYPE_STRING) {
        const char* cname = fl_value_get_string(item);
        if (cname != nullptr && cname[0] != '\0') {
          AddJsChannel(inst.get(), cname);
        }
      }
    }
  }
  RebuildUserScripts(inst.get());

  inst->load_changed_id = g_signal_connect(
      inst->webview, "load-changed", G_CALLBACK(OnLoadChanged), inst.get());
  inst->load_failed_id = g_signal_connect(inst->webview, "load-failed",
                                          G_CALLBACK(OnLoadFailed), inst.get());
  inst->notify_uri_id = g_signal_connect(inst->webview, "notify::uri",
                                         G_CALLBACK(OnNotifyUri), inst.get());
  inst->notify_progress_id = g_signal_connect(
      inst->webview, "notify::estimated-load-progress",
      G_CALLBACK(OnNotifyProgress), inst.get());
  inst->decide_policy_id = g_signal_connect(
      inst->webview, "decide-policy", G_CALLBACK(OnDecidePolicy), inst.get());
  inst->webview_destroy_id = g_signal_connect(
      inst->webview, "destroy", G_CALLBACK(OnWebViewDestroyed), inst.get());
  inst->clip_destroy_id =
      g_signal_connect(inst->clip_container, "destroy",
                       G_CALLBACK(OnClipContainerDestroyed), inst.get());

  GtkOverlay* overlay = EnsureOverlay(state);
  if (overlay != nullptr) {
    gtk_overlay_add_overlay(overlay, inst->clip_container);
    gtk_overlay_set_overlay_pass_through(overlay, inst->clip_container, TRUE);
  }
  gtk_widget_hide(inst->clip_container);

  bool has_html = false;
  const std::string initial_html = GetStringArg(args, "initialHtml", &has_html);
  bool has_url = false;
  const std::string initial_url = GetStringArg(args, "initialUrl", &has_url);

  if (has_html) {
    bool has_base = false;
    const std::string base_url =
        GetStringArg(args, "initialBaseUrl", &has_base);
    webkit_web_view_load_html(
        WEBKIT_WEB_VIEW(inst->webview), initial_html.c_str(),
        (has_base && !base_url.empty()) ? base_url.c_str() : nullptr);
  } else if (has_url && !initial_url.empty()) {
    const std::string method = GetStringArg(args, "initialMethod");
    LoadRequestOnWebView(inst.get(), initial_url,
                         method.empty() ? "GET" : method,
                         LookupMapValue(args, "initialHeaders"),
                         LookupMapValue(args, "initialBody"));
  }

  LinuxWebViewInstance* ptr = inst.get();
  state->instances[controller_id] = std::move(inst);
  return ptr;
}

}  // namespace

struct _WebviewCorePlugin {
  GObject parent_instance;
  PluginState* state;
};

G_DEFINE_TYPE(WebviewCorePlugin, webview_core_plugin, G_TYPE_OBJECT)

static void HandleMethodCall(WebviewCorePlugin* self, FlMethodCall* call) {
  PluginState* state = self->state;
  const gchar* method = fl_method_call_get_name(call);
  FlValue* args = fl_method_call_get_args(call);

  if (std::strcmp(method, "clearCookies") == 0) {
    WebKitWebContext* ctx = webkit_web_context_get_default();
    WebKitWebsiteDataManager* mgr =
        webkit_web_context_get_website_data_manager(ctx);
    webkit_website_data_manager_clear(mgr, WEBKIT_WEBSITE_DATA_COOKIES, 0,
                                      nullptr, OnClearCookiesFinished,
                                      g_object_ref(call));
    return;
  }

  if (std::strcmp(method, "setCookie") == 0) {
    const std::string name = GetStringArg(args, "name");
    const std::string value = GetStringArg(args, "value");
    const std::string domain = GetStringArg(args, "domain");
    std::string path = GetStringArg(args, "path");
    if (path.empty()) {
      path = "/";
    }
    if (!name.empty() && !domain.empty()) {
      WebKitWebContext* ctx = webkit_web_context_get_default();
      WebKitCookieManager* cm = webkit_web_context_get_cookie_manager(ctx);
      SoupCookie* cookie = soup_cookie_new(name.c_str(), value.c_str(),
                                           domain.c_str(), path.c_str(), -1);
      if (cookie != nullptr) {
        webkit_cookie_manager_add_cookie(cm, cookie, nullptr,
                                         OnAddCookieFinished,
                                         g_object_ref(call));
        soup_cookie_free(cookie);
        return;
      }
    }
    fl_method_call_respond_success(call, nullptr, nullptr);
    return;
  }

  int64_t controller_id = 0;
  if (!GetIntArg(args, "controllerId", &controller_id)) {
    fl_method_call_respond_error(call, "INVALID_ARGS", "Missing controllerId",
                                 nullptr, nullptr);
    return;
  }

  if (std::strcmp(method, "create") == 0) {
    CreateInstance(state, controller_id, args);
    FlValue* res = fl_value_new_int(0);
    fl_method_call_respond_success(call, res, nullptr);
    fl_value_unref(res);
    return;
  }

  if (std::strcmp(method, "dispose") == 0) {
    state->instances.erase(controller_id);
    if (state->registrar != nullptr) {
      FlView* fl_view = fl_plugin_registrar_get_view(state->registrar);
      if (fl_view != nullptr) {
        gtk_widget_queue_draw(GTK_WIDGET(fl_view));
      }
    }
    fl_method_call_respond_success(call, nullptr, nullptr);
    return;
  }

  std::map<int64_t, std::unique_ptr<LinuxWebViewInstance>>::iterator it =
      state->instances.find(controller_id);
  if (it == state->instances.end() || it->second == nullptr ||
      it->second->webview == nullptr || it->second->clip_container == nullptr) {
    fl_method_call_respond_success(call, nullptr, nullptr);
    return;
  }
  LinuxWebViewInstance* inst = it->second.get();

  if (std::strcmp(method, "setGeometry") == 0) {
    const bool visible = GetBoolArg(args, "visible", false);
    int64_t x = 0;
    int64_t y = 0;
    int64_t w = 0;
    int64_t h = 0;
    GetIntArg(args, "x", &x);
    GetIntArg(args, "y", &y);
    GetIntArg(args, "width", &w);
    GetIntArg(args, "height", &h);

    int64_t full_x = x;
    int64_t full_y = y;
    int64_t full_w = w;
    int64_t full_h = h;
    GetIntArg(args, "fullX", &full_x);
    GetIntArg(args, "fullY", &full_y);
    GetIntArg(args, "fullWidth", &full_w);
    GetIntArg(args, "fullHeight", &full_h);

    inst->x = static_cast<int>(x);
    inst->y = static_cast<int>(y);
    inst->width = static_cast<int>(w);
    inst->height = static_cast<int>(h);
    inst->full_x = static_cast<int>(full_x);
    inst->full_y = static_cast<int>(full_y);
    inst->full_width = static_cast<int>(full_w > 0 ? full_w : w);
    inst->full_height = static_cast<int>(full_h > 0 ? full_h : h);
    inst->visible = visible && w > 0 && h > 0;

    GtkOverlay* overlay = EnsureOverlay(state);
    if (overlay != nullptr &&
        gtk_widget_get_parent(inst->clip_container) == nullptr) {
      gtk_overlay_add_overlay(overlay, inst->clip_container);
    }

    if (!inst->visible) {
      if (overlay != nullptr) {
        gtk_overlay_set_overlay_pass_through(overlay, inst->clip_container,
                                             TRUE);
      }
      gtk_widget_hide(inst->clip_container);
      if (state->registrar != nullptr) {
        FlView* fl_view = fl_plugin_registrar_get_view(state->registrar);
        if (fl_view != nullptr) {
          gtk_widget_queue_draw(GTK_WIDGET(fl_view));
        }
      }
    } else {
      const int target_w = inst->full_width > 0 ? inst->full_width : 1;
      const int target_h = inst->full_height > 0 ? inst->full_height : 1;
      const int offset_x = inst->full_x - inst->x;
      const int offset_y = inst->full_y - inst->y;
      gtk_layout_set_size(GTK_LAYOUT(inst->clip_container),
                          static_cast<guint>(target_w),
                          static_cast<guint>(target_h));
      gtk_widget_set_size_request(inst->webview, target_w, target_h);
      gtk_layout_move(GTK_LAYOUT(inst->clip_container), inst->webview, offset_x,
                      offset_y);
      if (overlay != nullptr) {
        gtk_overlay_set_overlay_pass_through(overlay, inst->clip_container,
                                             FALSE);
        gtk_widget_queue_resize(GTK_WIDGET(overlay));
      }
      gtk_widget_show(inst->clip_container);
    }
    fl_method_call_respond_success(call, nullptr, nullptr);
    return;
  }

  if (std::strcmp(method, "loadHtmlString") == 0) {
    const std::string html = GetStringArg(args, "html");
    bool has_base = false;
    const std::string base_url = GetStringArg(args, "baseUrl", &has_base);
    webkit_web_view_load_html(
        WEBKIT_WEB_VIEW(inst->webview), html.c_str(),
        (has_base && !base_url.empty()) ? base_url.c_str() : nullptr);
    fl_method_call_respond_success(call, nullptr, nullptr);
    return;
  }

  if (std::strcmp(method, "loadRequest") == 0) {
    const std::string url = GetStringArg(args, "url");
    const std::string req_method = GetStringArg(args, "method");
    LoadRequestOnWebView(inst, url, req_method.empty() ? "GET" : req_method,
                         LookupMapValue(args, "headers"),
                         LookupMapValue(args, "body"));
    fl_method_call_respond_success(call, nullptr, nullptr);
    return;
  }

  if (std::strcmp(method, "loadFile") == 0) {
    const std::string path = GetStringArg(args, "path");
    gchar* file_uri = g_filename_to_uri(path.c_str(), nullptr, nullptr);
    if (file_uri != nullptr) {
      webkit_web_view_load_uri(WEBKIT_WEB_VIEW(inst->webview), file_uri);
      g_free(file_uri);
    }
    fl_method_call_respond_success(call, nullptr, nullptr);
    return;
  }

  if (std::strcmp(method, "loadFlutterAsset") == 0) {
    FlValue* res = fl_value_new_bool(FALSE);
    fl_method_call_respond_success(call, res, nullptr);
    fl_value_unref(res);
    return;
  }

  if (std::strcmp(method, "setJavaScriptEnabled") == 0) {
    const bool enabled = GetBoolArg(args, "enabled", true);
    WebKitSettings* settings =
        webkit_web_view_get_settings(WEBKIT_WEB_VIEW(inst->webview));
    g_object_set(G_OBJECT(settings), "enable-javascript",
                 enabled ? TRUE : FALSE, nullptr);
    fl_method_call_respond_success(call, nullptr, nullptr);
    return;
  }

  if (std::strcmp(method, "setBackgroundColor") == 0) {
    int64_t raw = 0;
    GetIntArg(args, "color", &raw);
    ApplyBackgroundColor(inst, static_cast<uint32_t>(raw));
    fl_method_call_respond_success(call, nullptr, nullptr);
    return;
  }

  if (std::strcmp(method, "setUserAgent") == 0) {
    bool has_ua = false;
    const std::string ua = GetStringArg(args, "userAgent", &has_ua);
    WebKitSettings* settings =
        webkit_web_view_get_settings(WEBKIT_WEB_VIEW(inst->webview));
    if (has_ua && !ua.empty()) {
      webkit_settings_set_user_agent(settings, ua.c_str());
    } else {
      webkit_settings_set_user_agent(settings,
                                     inst->default_user_agent.c_str());
    }
    fl_method_call_respond_success(call, nullptr, nullptr);
    return;
  }

  if (std::strcmp(method, "enableZoom") == 0) {
    inst->zoom_enabled = GetBoolArg(args, "enabled", true);
    if (!inst->zoom_enabled) {
      webkit_web_view_set_zoom_level(WEBKIT_WEB_VIEW(inst->webview), 1.0);
    }
    RebuildUserScripts(inst);
    fl_method_call_respond_success(call, nullptr, nullptr);
    return;
  }

  if (std::strcmp(method, "setHasNavigationDecision") == 0) {
    inst->has_navigation_decision = GetBoolArg(args, "enabled", false);
    fl_method_call_respond_success(call, nullptr, nullptr);
    return;
  }

  if (std::strcmp(method, "runJavaScript") == 0) {
    const std::string script = GetStringArg(args, "script");
    EvaluateScriptAsync(inst, script, call, false, false);
    return;
  }

  if (std::strcmp(method, "runJavaScriptReturningResult") == 0) {
    const std::string script = GetStringArg(args, "script");
    EvaluateScriptAsync(inst, script, call, true, false);
    return;
  }

  if (std::strcmp(method, "addJavaScriptChannel") == 0) {
    AddJsChannel(inst, GetStringArg(args, "name"));
    fl_method_call_respond_success(call, nullptr, nullptr);
    return;
  }

  if (std::strcmp(method, "removeJavaScriptChannel") == 0) {
    RemoveJsChannel(inst, GetStringArg(args, "name"));
    fl_method_call_respond_success(call, nullptr, nullptr);
    return;
  }

  if (std::strcmp(method, "reload") == 0) {
    webkit_web_view_reload(WEBKIT_WEB_VIEW(inst->webview));
    fl_method_call_respond_success(call, nullptr, nullptr);
    return;
  }

  if (std::strcmp(method, "stopLoading") == 0) {
    webkit_web_view_stop_loading(WEBKIT_WEB_VIEW(inst->webview));
    fl_method_call_respond_success(call, nullptr, nullptr);
    return;
  }

  if (std::strcmp(method, "canGoBack") == 0) {
    FlValue* res = fl_value_new_bool(
        webkit_web_view_can_go_back(WEBKIT_WEB_VIEW(inst->webview)));
    fl_method_call_respond_success(call, res, nullptr);
    fl_value_unref(res);
    return;
  }

  if (std::strcmp(method, "canGoForward") == 0) {
    FlValue* res = fl_value_new_bool(
        webkit_web_view_can_go_forward(WEBKIT_WEB_VIEW(inst->webview)));
    fl_method_call_respond_success(call, res, nullptr);
    fl_value_unref(res);
    return;
  }

  if (std::strcmp(method, "goBack") == 0) {
    if (webkit_web_view_can_go_back(WEBKIT_WEB_VIEW(inst->webview))) {
      webkit_web_view_go_back(WEBKIT_WEB_VIEW(inst->webview));
    }
    fl_method_call_respond_success(call, nullptr, nullptr);
    return;
  }

  if (std::strcmp(method, "goForward") == 0) {
    if (webkit_web_view_can_go_forward(WEBKIT_WEB_VIEW(inst->webview))) {
      webkit_web_view_go_forward(WEBKIT_WEB_VIEW(inst->webview));
    }
    fl_method_call_respond_success(call, nullptr, nullptr);
    return;
  }

  if (std::strcmp(method, "currentUrl") == 0) {
    const gchar* uri = webkit_web_view_get_uri(WEBKIT_WEB_VIEW(inst->webview));
    FlValue* res =
        uri != nullptr ? fl_value_new_string(uri) : fl_value_new_null();
    fl_method_call_respond_success(call, res, nullptr);
    fl_value_unref(res);
    return;
  }

  if (std::strcmp(method, "getTitle") == 0) {
    const gchar* title =
        webkit_web_view_get_title(WEBKIT_WEB_VIEW(inst->webview));
    FlValue* res =
        title != nullptr ? fl_value_new_string(title) : fl_value_new_null();
    fl_method_call_respond_success(call, res, nullptr);
    fl_value_unref(res);
    return;
  }

  if (std::strcmp(method, "scrollTo") == 0) {
    int64_t x = 0;
    int64_t y = 0;
    GetIntArg(args, "x", &x);
    GetIntArg(args, "y", &y);
    char buf[96];
    snprintf(buf, sizeof(buf), "window.scrollTo(%lld, %lld);",
             static_cast<long long>(x), static_cast<long long>(y));
    EvaluateScriptAsync(inst, buf, call, false, false);
    return;
  }

  if (std::strcmp(method, "scrollBy") == 0) {
    int64_t x = 0;
    int64_t y = 0;
    GetIntArg(args, "x", &x);
    GetIntArg(args, "y", &y);
    char buf[96];
    snprintf(buf, sizeof(buf), "window.scrollBy(%lld, %lld);",
             static_cast<long long>(x), static_cast<long long>(y));
    EvaluateScriptAsync(inst, buf, call, false, false);
    return;
  }

  if (std::strcmp(method, "getScrollPosition") == 0) {
    EvaluateScriptAsync(inst, "[window.scrollX || 0, window.scrollY || 0]",
                        call, false, true);
    return;
  }

  if (std::strcmp(method, "clearCache") == 0) {
    WebKitWebContext* ctx =
        webkit_web_view_get_context(WEBKIT_WEB_VIEW(inst->webview));
    WebKitWebsiteDataManager* mgr =
        webkit_web_context_get_website_data_manager(ctx);
    webkit_website_data_manager_clear(
        mgr,
        static_cast<WebKitWebsiteDataTypes>(WEBKIT_WEBSITE_DATA_DISK_CACHE |
                                            WEBKIT_WEBSITE_DATA_MEMORY_CACHE),
        0, nullptr, nullptr, nullptr);
    fl_method_call_respond_success(call, nullptr, nullptr);
    return;
  }

  if (std::strcmp(method, "clearLocalStorage") == 0) {
    WebKitWebContext* ctx =
        webkit_web_view_get_context(WEBKIT_WEB_VIEW(inst->webview));
    WebKitWebsiteDataManager* mgr =
        webkit_web_context_get_website_data_manager(ctx);
    webkit_website_data_manager_clear(mgr, WEBKIT_WEBSITE_DATA_LOCAL_STORAGE, 0,
                                      nullptr, nullptr, nullptr);
    fl_method_call_respond_success(call, nullptr, nullptr);
    return;
  }

  fl_method_call_respond_not_implemented(call, nullptr);
}

static void MethodCallCb(FlMethodChannel* /*channel*/,
                         FlMethodCall* method_call,
                         gpointer user_data) {
  WebviewCorePlugin* plugin = static_cast<WebviewCorePlugin*>(user_data);
  HandleMethodCall(plugin, method_call);
}

static void webview_core_plugin_dispose(GObject* object) {
  WebviewCorePlugin* self =
      G_TYPE_CHECK_INSTANCE_CAST(object, webview_core_plugin_get_type(),
                                 WebviewCorePlugin);
  if (self->state != nullptr) {
    self->state->instances.clear();
    if (self->state->overlay != nullptr) {
      if (self->state->child_pos_handler_id != 0) {
        g_signal_handler_disconnect(self->state->overlay,
                                    self->state->child_pos_handler_id);
        self->state->child_pos_handler_id = 0;
      }
      if (self->state->overlay_destroy_id != 0) {
        g_signal_handler_disconnect(self->state->overlay,
                                    self->state->overlay_destroy_id);
        self->state->overlay_destroy_id = 0;
      }
      self->state->overlay = nullptr;
    }
    if (self->state->channel != nullptr) {
      fl_method_channel_set_method_call_handler(self->state->channel, nullptr,
                                                nullptr, nullptr);
      g_clear_object(&self->state->channel);
    }
    if (self->state->registrar != nullptr) {
      g_clear_object(&self->state->registrar);
    }
    delete self->state;
    self->state = nullptr;
  }
  G_OBJECT_CLASS(webview_core_plugin_parent_class)->dispose(object);
}

static void webview_core_plugin_class_init(WebviewCorePluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = webview_core_plugin_dispose;
}

static void webview_core_plugin_init(WebviewCorePlugin* self) {
  self->state = new PluginState();
}

void webview_core_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  WebviewCorePlugin* plugin = static_cast<WebviewCorePlugin*>(
      g_object_new(webview_core_plugin_get_type(), nullptr));

  plugin->state->registrar = FL_PLUGIN_REGISTRAR(g_object_ref(registrar));
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  plugin->state->channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar),
      "com.infradise.webview_core", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(plugin->state->channel,
                                            MethodCallCb, g_object_ref(plugin),
                                            g_object_unref);
  g_object_unref(plugin);
}
