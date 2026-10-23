{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    thunar
  ];

  # Using declarative scheme for XML and forcing it to not get overwritten by xfconfd
  home.file.".config/xfce4/xfconf/xfce-perchannel-xml/thunar.xml" = {
    text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <channel name="thunar" version="1.0">

        <!-- View -->
        <property name="last-icon-view-zoom-level" type="string" value="THUNAR_ZOOM_LEVEL_50_PERCENT"/>
        <property name="last-details-view-zoom-level" type="string" value="THUNAR_ZOOM_LEVEL_38_PERCENT"/>
        <property name="last-show-hidden" type="bool" value="true"/>
        <property name="last-view" type="string" value="ThunarDetailsView"/>
        <property name="last-location-bar" type="string" value="ThunarLocationButtons"/>

        <!-- Sidebar & Window Geometry -->
        <property name="last-separator-position" type="int" value="250"/>
        <property name="shortcuts-icon-size" type="string" value="THUNAR_ICON_SIZE_24"/>
        <property name="tree-icon-size" type="string" value="THUNAR_ICON_SIZE_16"/>
        <property name="shortcuts-icon-emblems" type="bool" value="true"/>

        <!-- Sorting -->
        <property name="last-sort-column" type="string" value="THUNAR_COLUMN_NAME"/>
        <property name="last-sort-order" type="string" value="GTK_SORT_ASCENDING"/>
        <property name="misc-folders-first" type="bool" value="true"/>

        <!-- Columns -->
        <property name="last-details-view-visible-columns" type="string" value="THUNAR_COLUMN_NAME,THUNAR_COLUMN_DATE_MODIFIED,THUNAR_COLUMN_TYPE,THUNAR_COLUMN_SIZE"/>
        <property name="last-details-view-column-order" type="string" value="THUNAR_COLUMN_NAME,THUNAR_COLUMN_DATE_MODIFIED,THUNAR_COLUMN_TYPE,THUNAR_COLUMN_SIZE"/>

        <!-- Fix The Gap: Force tight column spacing instead of stretching across the screen -->
        <property name="last-details-view-fixed-columns" type="bool" value="true"/>
        <property name="last-details-view-column-widths" type="string" value="250,180,240,300,50,50,50,50,380,50,50,100,50,300"/>

        <!-- Behavior & Tweaks -->
        <property name="misc-thumbnail-mode" type="string" value="THUNAR_THUMBNAIL_MODE_ALWAYS"/>
        <property name="misc-date-style" type="string" value="THUNAR_DATE_STYLE_CUSTOM"/>
        <property name="misc-single-click" type="bool" value="false"/>
        <property name="misc-directory-specific-settings" type="bool" value="true"/>
        <property name="misc-image-preview-mode" type="string" value="THUNAR_IMAGE_PREVIEW_MODE_EMBEDDED"/>
        <property name="misc-symbolic-icons-in-sidepane" type="bool" value="false"/>
        <property name="misc-middle-click-in-tab" type="bool" value="false"/>
        <property name="misc-open-new-window-as-tab" type="bool" value="false"/>
        <property name="misc-transfer-use-partial" type="string" value="THUNAR_USE_PARTIAL_MODE_NEVER"/>
        <property name="misc-date-custom-style" type="string" value="%d %b %Y | %H:%M:%S"/>
        <property name="misc-volume-management" type="bool" value="false"/>
        <property name="misc-folder-item-count" type="string" value="THUNAR_FOLDER_ITEM_COUNT_ALWAYS"/>

      </channel>
    '';
    force = true;
  };
}
