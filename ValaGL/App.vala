/*
    App.vala
    Copyright (C) 2013 Maia Kozheva <sikon@ubuntu.com>

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:
    
    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.
    
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
    THE SOFTWARE.
*/

using SDL;

namespace ValaGL {

/**
 * The singleton application, responsible for managing the fullscreen SDL main window.
 */
public class App : GLib.Object {
	private enum EventCode {
		TIMER_EVENT
	}
	
	private unowned Screen screen;
	private bool done;
	private Canvas canvas;
	private SDL.Timer timer;
	
	private uint initial_rotation_angle = 30;
	private uint timer_ticks;
	
	/**
	 * Creates the application.
	 */
	public App() {
		// Do nothing
	}

	/**
	 * Runs the application.
	 */
	public void run () throws AppError {
		try {
			init_video ();
			init_timer ();

			while (!done) {
				process_events ();
				draw ();
			}
		} finally {
			if (timer != null) {
				timer.remove ();
				timer = null;
			}
			
			// Free the canvas and associated GL resources
			canvas = null;
		}
	}

	private void init_video () throws AppError {
		SDL.GL.set_attribute (GLattr.RED_SIZE, 8);
		SDL.GL.set_attribute (GLattr.GREEN_SIZE, 8);
		SDL.GL.set_attribute (GLattr.BLUE_SIZE, 8);
		SDL.GL.set_attribute (GLattr.ALPHA_SIZE, 8);
		SDL.GL.set_attribute (GLattr.DEPTH_SIZE, 16);
		SDL.GL.set_attribute (GLattr.DOUBLEBUFFER, 1);
		
		// Ask for multisampling if possible
		SDL.GL.set_attribute (GLattr.MULTISAMPLEBUFFERS, 1);
		SDL.GL.set_attribute (GLattr.MULTISAMPLESAMPLES, 4);
		
		// Enter fullscreen mode.
		// Note: Under X, this grabs all input and confines it to the application fullscreen window.
		// Therefore, we have to manually handle at least Alt-F4 and Alt-Tab, which we do in the keyboard handler.
		uint32 video_flags = SurfaceFlag.OPENGL | SurfaceFlag.FULLSCREEN;
		screen = Screen.set_video_mode (0, 0, 32, video_flags);
		
		if (screen == null) {
			throw new AppError.INIT ("Could not set video mode");
		}

		SDL.WindowManager.set_caption ("Vala OpenGL Skeletal Application", "");
		canvas = new Canvas();
		
		// Get the screen width and height and set up the viewport accordingly
		unowned VideoInfo video_info = VideoInfo.get ();
		canvas.resize_gl (video_info.current_w, video_info.current_h);
		canvas.update_scene_data (initial_rotation_angle);
	}
	
	private void init_timer () {
		timer = new SDL.Timer (10, (interval) => {
			// Executed in a separate thread, so we exchange information with the UI thread through events
			SDL.Event event = SDL.Event ();
			event.type = EventType.USEREVENT;
			event.user.code = EventCode.TIMER_EVENT;
			Event.push (event);
			return interval;
		});
	}

	private void draw () {
		canvas.paint_gl ();
		SDL.GL.swap_buffers ();
	}

	private void process_events () {
		Event event;
		
		while (Event.poll (out event) == 1) {
			switch (event.type) {
			case EventType.QUIT:
				done = true;
				break;
			case EventType.VIDEORESIZE:
				on_resize_event (event.resize);
				break;
			case EventType.KEYDOWN:
				on_keyboard_event (event.key);
				break;
			case EventType.USEREVENT:
				on_timer_event ();
				break;
			}
		}
	}
	
	private void on_resize_event (ResizeEvent event) {
		canvas.resize_gl (event.w, event.h);
	}

	private void on_keyboard_event (KeyboardEvent event) {
		switch (event.keysym.sym) {
		case KeySymbol.ESCAPE:
			// Close on Esc
			on_quit();
			break;
		case KeySymbol.F4:
			// Close on Alt-F4
			if ((event.keysym.mod & KeyModifier.LALT) != 0 || (event.keysym.mod & KeyModifier.RALT) != 0) {
				on_quit();
			}
			
			break;
		case KeySymbol.TAB:
			// Handle Alt-Tab (it won't be passed to the OS because SDL grabs keyboard input)
			if ((event.keysym.mod & KeyModifier.LALT) != 0 || (event.keysym.mod & KeyModifier.RALT) != 0) {
				SDL.WindowManager.iconify ();
			}
			
			break;
		default:
			// Insert any other keyboard combinations here.
			break;
		}
	}
	
	private void on_timer_event () {
		timer_ticks = (timer_ticks + 1) % 1800;
		canvas.update_scene_data (initial_rotation_angle + timer_ticks / 5.0f);
	}
	
	private void on_quit () {
		Event e = Event();
		e.type = EventType.QUIT;
		Event.push(e);
	}

	/**
	 * Application entry point.
	 * 
	 * Creates an instance of the ValaGL application and runs the SDL event loop
	 * until the user exits the application.
	 * 
	 * @param args Command line arguments. Ignored.
	 */
	public static int main (string[] args) {
		SDL.init (InitFlag.VIDEO | InitFlag.TIMER);

		try {
			new App ().run ();
		} catch (AppError e) {
			stderr.printf("Fatal error: %s\n", e.message);
			return 1;
		} finally {
			SDL.quit ();
		}
		
		return 0;
	}
}

}
