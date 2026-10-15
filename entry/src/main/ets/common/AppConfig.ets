/**
 * Shell configuration, shared by the ability and the web page.
 */

/** Self-hosted Travel Memory server rendered by this shell. */
export const SERVER_URL: string = 'https://top001.xin';
export const SERVER_HOST: string = 'top001.xin';

/** Marker appended to the native user agent, so the server can tell the app apart. */
export const APP_UA_SUFFIX: string = ' TravelMemoryHarmony/1.0';

/**
 * Edge-to-edge layout: the web view covers the whole screen, including the area
 * behind the status bar, so the page background paints edge to edge.
 *
 * The page itself is written for a browser (where the status bar lives outside
 * the viewport), so its own top chrome does not reserve the notch. When this is
 * on, `Index` injects a few pixels of top padding into the page's top bars and
 * matches the status bar icon colour to the page, which keeps everything
 * visible while staying immersive.
 */
export const IMMERSIVE: boolean = true;

/** net::ERR_ABORTED - emitted for user/Javascript cancelled loads, not a real failure. */
export const ERR_ABORTED: number = -3;
