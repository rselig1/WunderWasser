/**
 * 
 * PixelFlow | Copyright (C) 2016 Thomas Diewald - http://thomasdiewald.com
 * 
 * A Processing/Java library for high performance GPU-Computing (GLSL).
 * MIT License: https://opensource.org/licenses/MIT
 * 
 */



import com.thomasdiewald.pixelflow.java.DwPixelFlow;
import com.thomasdiewald.pixelflow.java.fluid.DwFluid2D;

import controlP5.Accordion;
import controlP5.ControlP5;
import controlP5.Group;
import controlP5.RadioButton;
import controlP5.Toggle;
import processing.core.*;
import processing.opengl.PGraphics2D;
import controlP5.CallbackListener;
import controlP5.CallbackEvent;
import controlP5.*;

import processing.serial.*;
import com.dhchoi.CountdownTimer;
import com.dhchoi.CountdownTimerService;


Serial port;
Serial port2;




  float[] velocities;
  
  public class MyFluidData implements DwFluid2D.FluidData{
    
     public float px, py, vy, radius, vscale, r, g, b, intensity, temperature;
     public float vx = 100f;
     public float dpdx;
     public float viscosity=100f;
     public float density = 100f;
    
    // update() is called during the fluid-simulation update step.
    @Override
    public void update(DwFluid2D fluid) {
     
      // Add impulse: density + velocity
      intensity = 1.0f;
      px = viewport_w/3;
      py = viewport_h * 0.6;
      radius = pipeRadius;
      vy = 0f;
      
      //Draw density object
      PGraphics2D pg_entrance = (PGraphics2D) createGraphics(viewport_w, viewport_h, P2D);
      pg_entrance.smooth(0);
      pg_entrance.beginDraw();
      pg_entrance.clear();
      pg_entrance.rect(px, py-pipeRadius, pipeLength/2, 2*pipeRadius); //density of fluid in the pipe
      pg_entrance.endDraw();

      //Add density
      fluid.addDensity(pg_entrance, 1, 1, 1);
      
      //Add parabolic velocity profile
      for (int i = (int) px; i < (int) px + 15; i++) {
        for (int j = (int) py - (int) pipeRadius; j < py + pipeRadius; j++){
          int y = abs(j - (int) py); //Find distance from centerline
          dpdx = -deltaP/pipeLength; //Pressure drop over pipe
          float v = vx / (pipeRadius*pipeRadius) * (y*y - pipeRadius*pipeRadius) * dpdx; //Velocity
          fluid.addVelocity(i, j, 2, v, 0);
        }
      }
    }
  }
  
  
  int viewport_w = 1057;
  int viewport_h = 594;
  int fluidgrid_scale = 1;
  
  int gui_w = 200;
  int gui_x = 20;
  int gui_y = 20;
  
  float pipeRadius = 100;
  float pipeLength = 200;
  float entranceVelocity = 100;
  float platesOrPipe = 0;
  float xpos = 400;
  float ypos = 400;            
  int xCenter = 900;
  int yCenter = 300;
  float yTop = yCenter + pipeRadius;
  float yBottom = yCenter - pipeRadius;
  
  float deltaP = pipeLength;
  
  boolean SERIAL = false; //Set to true if it is being run on the same computer as Arduino; false otherwise
  
  ControlP5 cp5;
  public RadioButton r; 
       
  DwFluid2D fluid;
  ObstaclePainter obstacle_painter;
  MyFluidData cb_fluid_data;
 
  // render targets
  PGraphics2D pg_fluid;
  //texture-buffer, for adding obstacles
  PGraphics2D pg_obstacles;
  //For identifying your location
  PGraphics2D pg_location;
  //For showing the obstacles pictorially
  PGraphics2D pg_obstacle_drawing;
  
  // some state variables for the GUI/display
  int     BACKGROUND_COLOR           = 0;
  boolean UPDATE_FLUID               = true;
  boolean DISPLAY_FLUID_TEXTURES     = true;
  boolean DISPLAY_FLUID_VECTORS      = true;
  int     DISPLAY_fluid_texture_mode = 3;
  

  public void settings() {
    size(viewport_w, viewport_h, P2D);
    smooth(2);
  }
  
  public void setup() {
   
    // main library context
    DwPixelFlow context = new DwPixelFlow(this);
    context.print();
    context.printGL();

    // fluid simulation
    fluid = new DwFluid2D(context, viewport_w, viewport_h, fluidgrid_scale);
    
    // set some simulation parameters
    fluid.param.dissipation_density     = 0.999f;
    fluid.param.dissipation_velocity    = 0.99f;
    fluid.param.dissipation_temperature = 0.80f;
    fluid.param.vorticity               = 0.00f;
    //Temperature should not cause fluid to float up
    fluid.param.apply_buoyancy = false;
    
    // interface for adding data to the fluid simulation
    cb_fluid_data = new MyFluidData();
    fluid.addCallback_FluiData(cb_fluid_data);
   
    // pgraphics for fluid
    pg_fluid = (PGraphics2D) createGraphics(viewport_w, viewport_h, P2D);
    pg_fluid.smooth(4);
    pg_fluid.beginDraw();
    pg_fluid.background(BACKGROUND_COLOR);
    pg_fluid.endDraw();
    
    // pgraphics for obstacles
    pg_obstacles = (PGraphics2D) createGraphics(viewport_w, viewport_h, P2D);
    pg_obstacles.smooth(0);
    pg_obstacles.beginDraw();
    pg_obstacles.clear();
    
    //pgraphics for location
    pg_location = (PGraphics2D) createGraphics(viewport_w, viewport_h, P2D);
    pg_location.smooth(0);
    pg_location.beginDraw();
    pg_location.clear();
    
    // pgraphics for obstacles
    pg_obstacle_drawing = (PGraphics2D) createGraphics(viewport_w, viewport_h, P2D);
    pg_obstacle_drawing.smooth(0);
    pg_obstacle_drawing.beginDraw();
    pg_obstacle_drawing.clear();
   
    pg_obstacles.endDraw(); 
    
    // class, that manages interactive drawing (adding/removing) of obstacles
    obstacle_painter = new ObstaclePainter(pg_obstacles);
    
    createGUI();
    
    frameRate(60);
    
    //Serial setup
    if(SERIAL) {
     println(Serial.list()); //Print out list of connected port

     // Open the port that the Arduino board is connected to (in this case #0)
     // Make sure to open the port at the same speed Arduino is using (9600bps)
     port = new Serial(this, Serial.list()[0], 9600); //Change 0 based on Serial.list() printout
     port2 = new Serial(this, Serial.list()[1], 9600); //Change 1 based on Serial.list() printout
     
    
    }
    
    
  }
  
 /* void onTickEvent(CountdownTimer t, long timeLeftUntilFinish){
    if (haply_board_data_available()){
      angles.set(haply_2DoF.get_device_angles());
      pos_ee.set(haply_2DoF.get_device_position(angles.array()));
      
      println("Position");
      println(pos_ee.array()[0]);
      println(pos_ee.array()[1]);
      
     xpos = pos_ee.array()[0];
     ypos = pos_ee.array()[1];
     
     draw();

    }
    
  }*/

  public void draw() {    
    
    // update simulation
    if(UPDATE_FLUID){
      fluid.addObstacles(pg_obstacles);
      fluid.update(); 
    }

    //Print out integer values of fluid at specific position
    if (!SERIAL) {
       velocities = fluid.getVelocity(velocities, (int) xpos, ((int) viewport_h - (int) ypos), 1, 1);
       println("X pos: " + xpos + " X velocity: " + velocities[0]);
       println("Y pos: " + ypos + " Y velocity: " + velocities[1]);
    } else { //Print velocities to serial
     //Write X and Y velocities to Haply
      port.write("X");
      port.write((int) velocities[0]);
      port.write("Y");
      port.write((int) velocities[1]);
      //Write pressure to Hapkit    
      int px = viewport_w/3;
      int pxRight = px + (int) pipeLength;
      //Assume 0 pressure on the right, pressure increasing to the left
      int pressureRight = 0;
      float pressureGradient = (deltaP/pipeLength);
      int pressure = pressureRight + (int) ((pxRight - (int) xpos)*pressureGradient);
      port2.write(pressure);
    }
    
    //IDEA FOR ARDUINO SERIAL READING CODE:
    /*
    //Haply
    int incomingByte;
    int incomingXVelInt;
    int incomingYVelInt;
    void loop(){
      if (Serial.available() > 0) {
        incomingByte = Serial.read();
        if (incomingByte == "X") {
          incomingXVelInt = Serial.parseInt();
        } else if (incomingByte == "Y"){
          incomingYVelInt = Serial.parseInt();
        }
      }
    
    //Hapkit
       int incomingPressure;
    void loop(){
      if (Serial.available() > 0) {
        incomingPressure = Serial.read();
      }
    }
    */
    
    // clear render target
    pg_fluid.beginDraw();
    pg_fluid.background(BACKGROUND_COLOR);
    pg_fluid.endDraw();
    
    // render fluid stuff
    if(DISPLAY_FLUID_TEXTURES){
      // render: density (0), temperature (1), pressure (2), velocity (3)
      fluid.renderFluidTextures(pg_fluid, DISPLAY_fluid_texture_mode);
    }
    
    if(DISPLAY_FLUID_VECTORS){
      // render: velocity vector field
      fluid.renderFluidVectors(pg_fluid, 10);
    }
    
    pg_fluid.beginDraw();
    pg_fluid.endDraw();
    
    //Draw obstacle outline (Just for display)
    pg_obstacle_drawing.beginDraw();
    pg_obstacle_drawing.clear();
    int xStart = viewport_w/3;
    int yStart = (int) (viewport_h * 0.4); 
    int yTop = yStart + (int) pipeRadius;
    int yBottom = yStart - (int) pipeRadius;
    platesOrPipe = (r.getArrayValue()[1] > 0) ? 1 : 0;
    if(platesOrPipe==1){
      //Draw a pipe
      pg_obstacle_drawing.noFill();
      pg_obstacle_drawing.stroke(255);
      pg_obstacle_drawing.ellipse(xStart+pipeLength, yStart, pipeRadius/2, 2*pipeRadius);
      pg_obstacle_drawing.stroke(255);
      pg_obstacle_drawing.line(xStart, yTop, xStart + pipeLength, yTop);
      pg_obstacle_drawing.stroke(255);
      pg_obstacle_drawing.line(xStart, yBottom, xStart + pipeLength, yBottom);
      pg_obstacle_drawing.noFill();
      pg_obstacle_drawing.arc(xStart, yStart, pipeRadius/2, 2*pipeRadius, HALF_PI, PI+HALF_PI);
    } else {
      //Draw parallel plates
      pg_obstacle_drawing.stroke(255);
      pg_obstacle_drawing.line(xStart, yTop, xStart + pipeLength, yTop);
      pg_obstacle_drawing.stroke(255);
      pg_obstacle_drawing.line(xStart, yBottom, xStart + pipeLength, yBottom); 
    }
    pg_obstacle_drawing.endDraw();
    
    //Draw actual obstacle (blocks fluid from flowing)
    pg_obstacles.beginDraw();
    pg_obstacles.clear();
    pg_obstacles.fill(255);
    pg_obstacles.rect(xStart, 0, pipeLength, yTop - 2* pipeRadius); //Top barrier
    pg_obstacles.rect(xStart, yBottom + 2*pipeRadius, pipeLength, yTop); //Bottom barrier
    pg_obstacles.rect(0, 0, xStart, viewport_h);
    pg_obstacles.endDraw();
    
    //Draw ellipse to mark location 
    pg_location.beginDraw();   
    pg_location.clear();
    pg_location.fill(140);
    pg_location.ellipse(xpos, ypos, 10, 10);
    pg_location.endDraw();

    //Draw all displays 
    image(pg_obstacles, 0, 0);
    image(pg_fluid    , 0, 0);
    image(pg_location, 0, 0);
    image(pg_obstacle_drawing, 0, 0);

    // info
    String txt_fps = String.format(getClass().getName()+ "   [size %d/%d]   [frame %d]   [fps %6.2f]", fluid.fluid_w, fluid.fluid_h, fluid.simulation_step, frameRate);
    surface.setTitle(txt_fps);
   
  
  }
  


  public void mousePressed(){
    //if(mouseButton == CENTER ) obstacle_painter.beginDraw(1); // add obstacles
    //if(mouseButton == RIGHT  ) obstacle_painter.beginDraw(2); // remove obstacles
    xpos = mouseX;
    ypos = mouseY;
  }
  
  public void mouseDragged(){
   // obstacle_painter.draw();
   xpos = mouseX;
   ypos = mouseY;
  }
  
  public void mouseReleased(){
    //obstacle_painter.endDraw();
    xpos = mouseX;
    ypos = mouseY;
  }
  

  public void fluid_resizeUp(){
    fluid.resize(width, height, fluidgrid_scale = max(1, --fluidgrid_scale));
  }
  public void fluid_resizeDown(){
    fluid.resize(width, height, ++fluidgrid_scale);
  }
  public void fluid_reset(){
    fluid.reset();
  }
  public void fluid_togglePause(){
    UPDATE_FLUID = !UPDATE_FLUID;
  }
  public void fluid_displayMode(int val){
    DISPLAY_fluid_texture_mode = val;
    DISPLAY_FLUID_TEXTURES = DISPLAY_fluid_texture_mode != -1;
  }
  public void fluid_displayVelocityVectors(int val){
    DISPLAY_FLUID_VECTORS = val != -1;
  }

  public void keyReleased(){
    if(key == 'p') fluid_togglePause(); // pause / unpause simulation
    if(key == '+') fluid_resizeUp();    // increase fluid-grid resolution
    if(key == '-') fluid_resizeDown();  // decrease fluid-grid resolution
    if(key == 'r') fluid_reset();       // restart simulation
    
    if(key == '1') DISPLAY_fluid_texture_mode = 0; // density
    if(key == '3') DISPLAY_fluid_texture_mode = 2; // pressure
    if(key == '4') DISPLAY_fluid_texture_mode = 3; // velocity
    
    if(key == 'q') DISPLAY_FLUID_TEXTURES = !DISPLAY_FLUID_TEXTURES;
    if(key == 'w') DISPLAY_FLUID_VECTORS  = !DISPLAY_FLUID_VECTORS;
    
    if (keyCode == 40){
      //Down arrow
        ypos+=5;
    } else if (keyCode == 38) {
      //Up arrow 
      ypos-=5;
    } else if (keyCode == 37){
      xpos-=5; //left arrow
    } else if (keyCode == 39) {
      xpos+=5; //right arrow
    }
  }
 

  
  public void createGUI(){
    cp5 = new ControlP5(this);
    
    int sx, sy, px, py, oy;
    
    sx = 100; sy = 14; oy = (int)(sy*1.5f);
    

    ////////////////////////////////////////////////////////////////////////////
    // GUI - FLUID
    ////////////////////////////////////////////////////////////////////////////
    Group group_fluid = cp5.addGroup("fluid");
    {
      group_fluid.setHeight(20).setSize(gui_w, 300)
      .setBackgroundColor(color(16, 180)).setColorBackground(color(16, 180));
      group_fluid.getCaptionLabel().align(CENTER, CENTER);
      
      px = 10; py = 15;
      
      cp5.addButton("reset").setGroup(group_fluid).plugTo(this, "fluid_reset"     ).setSize(80, 18).setPosition(px    , py);
      cp5.addButton("+"    ).setGroup(group_fluid).plugTo(this, "fluid_resizeUp"  ).setSize(39, 18).setPosition(px+=82, py);
      cp5.addButton("-"    ).setGroup(group_fluid).plugTo(this, "fluid_resizeDown").setSize(39, 18).setPosition(px+=41, py);
    
      //Listener for plates or pipe radio buttons; sets platesOrPipe and resets fluid    
      ControlListener c = new ControlListener(){
        public void controlEvent(ControlEvent theEvent){
          platesOrPipe = theEvent.getValue();
          fluid_reset();
        }
      };    
      
      //Listener for geometry changes; resets fluid
       CallbackListener cb = new CallbackListener() {
        public void controlEvent(CallbackEvent theEvent) {
          fluid_reset(); 
        }
      };
      
      //Geometry radio buttons (plates or pipe)
      r = cp5.addRadioButton("radioButton")
         .setGroup(group_fluid)
         .setPosition(px - (82+41), py+=30)
         .addItem("Plate",0)
         .addItem("Pipe",1)
         .addListener(c);
      
      //Sliders for fluid parameters
      px = 10;
      cp5.addSlider("velocity").setGroup(group_fluid).setSize(sx, sy).setPosition(px, py+=(int)(oy*1.5f))
          .setRange(0, 1).setValue(fluid.param.dissipation_velocity).plugTo(fluid.param, "dissipation_velocity"); //actually viscosity
      
      cp5.addSlider("density").setGroup(group_fluid).setSize(sx, sy).setPosition(px, py+=oy)
          .setRange(0, 1).setValue(fluid.param.dissipation_density).plugTo(fluid.param, "dissipation_density");
          
      cp5.addSlider("pipeRadius").setGroup(group_fluid).setSize(sx, sy).setPosition(px, py+=oy)
          .setRange(50, 300).setValue(pipeRadius).plugTo(pipeRadius).onChange(cb);
          
      cp5.addSlider("pipeLength").setGroup(group_fluid).setSize(sx, sy).setPosition(px, py+=oy)
          .setRange(viewport_w/10, 0.7*viewport_w).setValue(pipeLength).plugTo(pipeLength).onChange(cb);
     
//     cp5.addSlider("xpos").setGroup(group_fluid).setSize(sx, sy).setPosition(px, py+=oy)
//            .setRange(0, viewport_w).setValue(xpos).plugTo(xpos);
     
 //    cp5.addSlider("ypos").setGroup(group_fluid).setSize(sx, sy).setPosition(px, py+=oy)
 //            .setRange(0, viewport_h).setValue(ypos).plugTo(ypos);
                               
     cp5.addSlider("vx").setGroup(group_fluid).setSize(sx, sy).setPosition(px, py+=oy)
             .setRange(0, 1000).setValue(cb_fluid_data.vx).plugTo(cb_fluid_data, "vx").onChange(cb);
             
      cp5.addSlider("temperature").setGroup(group_fluid).setSize(sx, sy).setPosition(px, py+=oy)
          .setRange(0, 1).setValue(fluid.param.dissipation_temperature).plugTo(fluid.param, "dissipation_temperature");
          
      cp5.addSlider("deltaP").setGroup(group_fluid).setSize(sx, sy).setPosition(px, py+=oy)
          .setRange(50, 2000).setValue(deltaP).plugTo(deltaP).onChange(cb);
          
  /*cp5.addSlider("vorticity").setGroup(group_fluid).setSize(sx, sy).setPosition(px, py+=oy)
          .setRange(0, 1).setValue(fluid.param.vorticity).plugTo(fluid.param, "vorticity");
          
      cp5.addSlider("iterations").setGroup(group_fluid).setSize(sx, sy).setPosition(px, py+=oy)
          .setRange(0, 80).setValue(fluid.param.num_jacobi_projection).plugTo(fluid.param, "num_jacobi_projection");
            
      cp5.addSlider("timestep").setGroup(group_fluid).setSize(sx, sy).setPosition(px, py+=oy)
          .setRange(0, 1).setValue(fluid.param.timestep).plugTo(fluid.param, "timestep");
          
      cp5.addSlider("gridscale").setGroup(group_fluid).setSize(sx, sy).setPosition(px, py+=oy)
          .setRange(0, 50).setValue(fluid.param.gridscale).plugTo(fluid.param, "gridscale");*/
      
      RadioButton rb_setFluid_DisplayMode = cp5.addRadio("fluid_displayMode").setGroup(group_fluid).setSize(80,18).setPosition(px, py+=(int)(oy*1.5f))
          .setSpacingColumn(2).setSpacingRow(2).setItemsPerRow(2)
          .addItem("Temperature", 1)
          .addItem("Pressure"   ,2)
          .addItem("Velocity"   ,3)
          .activate(DISPLAY_fluid_texture_mode);
      for(Toggle toggle : rb_setFluid_DisplayMode.getItems()) toggle.getCaptionLabel().alignX(CENTER);
      
      cp5.addRadio("fluid_displayVelocityVectors").setGroup(group_fluid).setSize(18,18).setPosition(px, py+=(int)(oy*2.5f))
          .setSpacingColumn(2).setSpacingRow(2).setItemsPerRow(1)
          .addItem("Velocity Vectors", 0)
          .activate(DISPLAY_FLUID_VECTORS ? 0 : 2);
    }
    
    ////////////////////////////////////////////////////////////////////////////
    // GUI - ACCORDION
    ////////////////////////////////////////////////////////////////////////////
    cp5.addAccordion("acc").setPosition(gui_x, gui_y).setWidth(gui_w).setSize(gui_w, height)
      .setCollapseMode(Accordion.MULTI)
      .addItem(group_fluid)
      .open(4);
  }
  

  //I did not touch any of this in case we want to paint obstacles later -jc
  public class ObstaclePainter{
    
    // 0 ... not drawing
    // 1 ... adding obstacles
    // 2 ... removing obstacles
    public int draw_mode = 0;
    PGraphics pg;
    
    float size_paint = 15;
    float size_clear = size_paint * 2.5f;
    
    float paint_x, paint_y;
    float clear_x, clear_y;
    
    int shading = 64;
    
    public ObstaclePainter(PGraphics pg){
      this.pg = pg;
    }
    
    public void beginDraw(int mode){
      paint_x = mouseX;
      paint_y = mouseY;
      this.draw_mode = mode;
      if(mode == 1){
        pg.beginDraw();
        pg.blendMode(REPLACE);
        pg.noStroke();
        pg.fill(shading);
        pg.ellipse(mouseX, mouseY, size_paint, size_paint);
        pg.endDraw();
      }
      if(mode == 2){
        clear(mouseX, mouseY);
      }
    }
    
    public boolean isDrawing(){
      return draw_mode != 0;
    }
    
    public void draw(){
      paint_x = mouseX;
      paint_y = mouseY;
      if(draw_mode == 1){
        pg.beginDraw();
        pg.blendMode(REPLACE);
        pg.strokeWeight(size_paint);
        pg.stroke(shading);
        pg.line(mouseX, mouseY, pmouseX, pmouseY);
        pg.endDraw();
      }
      if(draw_mode == 2){
        clear(mouseX, mouseY);
      }
      

      
    }

    public void endDraw(){
      this.draw_mode = 0;
    }
    
    public void clear(float x, float y){
      clear_x = x;
      clear_y = y;
      pg.beginDraw();
      pg.blendMode(REPLACE);
      pg.noStroke();
      pg.fill(0, 0);
      pg.ellipse(x, y, size_clear, size_clear);
      pg.endDraw();
    }
    
    public void displayBrush(PGraphics dst){
      if(draw_mode == 1){
        dst.strokeWeight(1);
        dst.stroke(0);
        dst.fill(200,50);
        dst.ellipse(paint_x, paint_y, size_paint, size_paint);
      }
      if(draw_mode == 2){
        dst.strokeWeight(1);
        dst.stroke(200);
        dst.fill(200,100);
        dst.ellipse(clear_x, clear_y, size_clear, size_clear);
      }
    }
    

  }
  
  
  
  