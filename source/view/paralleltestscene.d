/*
Copyright: Marcelo S. N. Mancini (Hipreme|MrcSnm), 2018 - 2021
License:   [https://creativecommons.org/licenses/by/4.0/|CC BY-4.0 License].
Authors: Marcelo S. N. Mancini

	Copyright Marcelo S. N. Mancini 2018 - 2021.
Distributed under the CC BY-4.0 License.
   (See accompanying file LICENSE.txt or copy at
	https://creativecommons.org/licenses/by/4.0/
*/

module view.paralleltestscene;
import hiprenderer;
import data.image;
import graphics.g2d;
import data.assetpacker;
import data.assetmanager;
import view.scene;

class ParallelTestScene : Scene
{
    HipSpriteBatch batch;
    HipSprite spr;
    this()
    {
        batch = new HipSpriteBatch();
        spr = new HipSprite("./assets/graphics/sprites/rex.png");

        // HipAssetMnager.loadImage("./assets/graphics/sprites/rex.png", (Image img)
        // {
        
        // }, true);
        
    }
    override void render()
    {
        HipAssetManager.checkLoad();
        batch.begin();
        if(spr.texture.texture.img !is null)
        {
            batch.draw(spr);
        }
        batch.end();
    }

}