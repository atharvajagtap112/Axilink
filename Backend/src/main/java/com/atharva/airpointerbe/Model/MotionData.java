package com.atharva.airpointerbe.Model;



public class MotionData {
    private double dx;
    private double dy;
    private String action;
    private double scroll_dy;
    private String text;
    public MotionData() {}

    public MotionData(double dx, double dy, String action, double scroll_dy, String text ) {
        this.dx = dx;
        this.action=action;
        this.scroll_dy=scroll_dy;
        this.text=text;
        this.dy = dy;
    }


    public String getText() {
        return text;
    }

    public void setText(String text) {
        this.text = text;
    }

    public double getScroll_dy() {
        return scroll_dy;
    }

    public void setScroll_dy(double scroll_dy) {
        this.scroll_dy = scroll_dy;
    }

    public String getAction() {
        return action;
    }

    public void setAction(String action) {
        this.action = action;
    }

    public double getDx() {
        return dx;
    }

    public void setDx(double dx) {
        this.dx = dx;
    }

    public double getDy() {
        return dy;
    }

    public void setDy(double dy) {
        this.dy = dy;
    }
}
