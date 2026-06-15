{ config, pkgs, ... }:
{
  services.mako = {
    enable = true;
    settings = {
      font = "Terminus 12";
      background-color = "#0d0d0d";
      text-color = "#d3d3d3";
      border-color = "#4a4a6a";
      border-radius = 0;
      border-size = 1;
      width = 320;
      padding = "10";
      margin = "12";
      default-timeout = 6000;
      anchor = "top-right";
      on-notify = "exec paplay ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/message.oga";

      "urgency=low" = {
        background-color = "#0d0d0d";
        text-color = "#d3d3d3";
        border-color = "#4a4a6a";
      };

      "urgency=normal" = {
        background-color = "#0d0d0d";
        text-color = "#d3d3d3";
        border-color = "#6b7fb5";
      };

      "urgency=critical" = {
        background-color = "#0d0d0d";
        text-color = "#d4527a";
        border-color = "#8b3a5a";
        default-timeout = 0;
      };
    };
  };
}
