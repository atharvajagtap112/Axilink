package com.atharva.airpointerbe.Model;

public class ScreenFrameMessage {
    private String image;
    private String imageSegment;
    private String frameId;
    private Integer segmentIndex;
    private Integer totalSegments;
    private Double aspectRatio;
    private Long timestamp;
    private Double segmentY;
    private Double segmentHeight;
    private String imageChunk;
    private Integer chunkIndex;
    private Integer totalChunks;

    // Default constructor
    public ScreenFrameMessage() {}

    // Getters and setters
    public String getImage() {
        return image;
    }

    public void setImage(String image) {
        this.image = image;
    }

    public String getImageSegment() {
        return imageSegment;
    }

    public void setImageSegment(String imageSegment) {
        this.imageSegment = imageSegment;
    }

    public String getFrameId() {
        return frameId;
    }

    public void setFrameId(String frameId) {
        this.frameId = frameId;
    }

    public Integer getSegmentIndex() {
        return segmentIndex;
    }

    public void setSegmentIndex(Integer segmentIndex) {
        this.segmentIndex = segmentIndex;
    }

    public Integer getTotalSegments() {
        return totalSegments;
    }

    public void setTotalSegments(Integer totalSegments) {
        this.totalSegments = totalSegments;
    }

    public Double getAspectRatio() {
        return aspectRatio;
    }

    public void setAspectRatio(Double aspectRatio) {
        this.aspectRatio = aspectRatio;
    }

    public Long getTimestamp() {
        return timestamp;
    }

    public void setTimestamp(Long timestamp) {
        this.timestamp = timestamp;
    }

    public Double getSegmentY() {
        return segmentY;
    }

    public void setSegmentY(Double segmentY) {
        this.segmentY = segmentY;
    }

    public Double getSegmentHeight() {
        return segmentHeight;
    }

    public void setSegmentHeight(Double segmentHeight) {
        this.segmentHeight = segmentHeight;
    }

    public String getImageChunk() {
        return imageChunk;
    }

    public void setImageChunk(String imageChunk) {
        this.imageChunk = imageChunk;
    }

    public Integer getChunkIndex() {
        return chunkIndex;
    }

    public void setChunkIndex(Integer chunkIndex) {
        this.chunkIndex = chunkIndex;
    }

    public Integer getTotalChunks() {
        return totalChunks;
    }

    public void setTotalChunks(Integer totalChunks) {
        this.totalChunks = totalChunks;
    }
}