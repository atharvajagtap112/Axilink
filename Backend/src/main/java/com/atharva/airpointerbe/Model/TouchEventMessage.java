package com.atharva.airpointerbe.Model;

import com.fasterxml.jackson.annotation.JsonProperty;

public class TouchEventMessage {

    @JsonProperty("xPercent")
    private double xPercent;

    @JsonProperty("yPercent")
    private double yPercent;

    @JsonProperty("clickType")
    private String clickType;

    // Getters and setters
    public double getXPercent() { return xPercent; }
    public void setXPercent(double xPercent) { this.xPercent = xPercent; }
    public double getYPercent() { return yPercent; }
    public void setYPercent(double yPercent) { this.yPercent = yPercent; }
    public String getClickType() { return clickType; }
    public void setClickType(String clickType) { this.clickType = clickType; }

    @Override
    public String toString() {
        return "TouchEventMessage{" +
                "xPercent=" + xPercent +
                ", yPercent=" + yPercent +
                ", clickType='" + clickType + '\'' +
                '}';
    }
}
