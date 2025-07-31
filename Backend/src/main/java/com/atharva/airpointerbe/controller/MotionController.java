package com.atharva.airpointerbe.controller;



import com.atharva.airpointerbe.Model.ModeMessage;
import com.atharva.airpointerbe.Model.MotionData;
import com.atharva.airpointerbe.Model.ScreenFrameMessage;
import com.atharva.airpointerbe.Model.TouchEventMessage;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.messaging.handler.annotation.DestinationVariable;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.PathVariable;

import java.util.HashMap;
import java.util.Map;

@Controller
public class MotionController {

    @Autowired
    private SimpMessagingTemplate messagingTemplate;

    // Flutter sends data to /app/move
    @MessageMapping("/move/{code}")
    public void receiveMotion(@DestinationVariable String code, MotionData motionData) {
//        System.out.println("Received motion data: " + motionData);


        if (motionData.getAction() != null) {
            String action = motionData.getAction();

            if (action.equals("scroll")){
                messagingTemplate.convertAndSend("/topic/move/"+code, Map.of(
                                                                        "action", action,
                                                                       "scroll_dy", motionData.getScroll_dy()));
            }
            else if (action.equals("type")){
                messagingTemplate.convertAndSend("/topic/move/"+code
                        , Map.of(
                        "action",action,
                          "text",motionData.getText()
                ));
            }
            else {
                messagingTemplate.convertAndSend("/topic/move/"+code, Map.of("action", action));

            }

            return;
        }

        // If no action, treat as movement
        double dx = motionData.getDx();
        double dy = motionData.getDy();

        messagingTemplate.convertAndSend("/topic/move/"+code, Map.of(
                "dx", dx,
                "dy", dy
        ));
    }

    @MessageMapping("/screen/{code}")
    public void receiveScreen(@DestinationVariable String code, ScreenFrameMessage screenFrameMessage) {
        // Create a response map with all available fields
        Map<String, Object> responseMap = new HashMap<>();

        // Add basic image data if available
        if (screenFrameMessage.getImage() != null) {
            responseMap.put("image", screenFrameMessage.getImage());
        }

        // Add image segment data if available
        if (screenFrameMessage.getImageSegment() != null) {
            responseMap.put("imageSegment", screenFrameMessage.getImageSegment());
            responseMap.put("segmentIndex", screenFrameMessage.getSegmentIndex());
            responseMap.put("totalSegments", screenFrameMessage.getTotalSegments());
            responseMap.put("frameId", screenFrameMessage.getFrameId());
            responseMap.put("segmentY", screenFrameMessage.getSegmentY());
            responseMap.put("segmentHeight", screenFrameMessage.getSegmentHeight());
        }

        // Add image chunk data if available
        if (screenFrameMessage.getImageChunk() != null) {
            responseMap.put("imageChunk", screenFrameMessage.getImageChunk());
            responseMap.put("chunkIndex", screenFrameMessage.getChunkIndex());
            responseMap.put("totalChunks", screenFrameMessage.getTotalChunks());
            responseMap.put("frameId", screenFrameMessage.getFrameId());
        }

        // Add common fields if available
        if (screenFrameMessage.getAspectRatio() != null) {
            responseMap.put("aspectRatio", screenFrameMessage.getAspectRatio());
        }

        if (screenFrameMessage.getTimestamp() != null) {
            responseMap.put("timestamp", screenFrameMessage.getTimestamp());
        }

        // Send the complete response
        messagingTemplate.convertAndSend("/topic/screen/"+code, responseMap);
    }

    @MessageMapping("/mode/{code}")
    public void setMode(@DestinationVariable String code, ModeMessage modeMsg) {
        messagingTemplate.convertAndSend("/topic/mode/"+code, Map.of("mode", modeMsg.getMode()));
    }

    @MessageMapping("/touch/{code}")
    public void receiveTouch(@DestinationVariable String code,
                             @Payload String rawPayload,  // Add this to see raw JSON
                             TouchEventMessage touchEvent) {
        // Print the raw payload to see what's actually arriving
//        System.out.println(touchEvent.getXPercent());

        messagingTemplate.convertAndSend("/topic/touch/"+code, Map.of(
                "xPercent",touchEvent.getXPercent(),
                  "yPercent",touchEvent.getYPercent(),
                "clickType",touchEvent.getClickType()
        ));

    }

}
