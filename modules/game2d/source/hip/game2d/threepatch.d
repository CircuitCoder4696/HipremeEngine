module hip.game2d.threepatch;

public import hip.api.renderer.texture;
public import hip.game2d.sprite;
import hip.api.assets.assets_binding;
import hip.game2d.renderer_data;

enum ThreePatchOrientation
{
    horizontal,
    vertical,
    inferred
}


class ThreePatch
{
    int x, y;
    int width, height;
    HipSpriteVertex[4*3] vertices;
    HipSprite[3] sprites;
    ThreePatchOrientation orientation;
    ThreePatchOrientation inferredOrientation = ThreePatchOrientation.inferred;

    this(string texturePath, ThreePatchOrientation orientation = ThreePatchOrientation.inferred)
    {
        this(loadTexture(texturePath).awaitAs!IHipTexture, width, height, orientation);
    }
    this(IHipTexture texture, int width, int height, ThreePatchOrientation orientation = ThreePatchOrientation.inferred)
    {
        for(int i = 0; i < 3; i++)
            sprites[i] = new HipSprite(texture);

        this.orientation = orientation;
        this.inferredOrientation = infer(width, height);
        setSize(width, height);
    }
    pragma(inline) ThreePatchOrientation getOrientation()
    {
        if(orientation == ThreePatchOrientation.inferred)
            return inferredOrientation;
        return orientation;
    }
    void setOrientation(ThreePatchOrientation ori = ThreePatchOrientation.horizontal)
    {
        if(orientation == ThreePatchOrientation.inferred)
            return setOrientation(inferredOrientation);
        if(ori != orientation)
        {
            orientation = ori;
            build();
        }
    }

    void setSize(int width, int height)
    {
        this.width = width;
        this.height = height;

        
        if(getOrientation == ThreePatchOrientation.horizontal)
        {
            float rw = sprites[0].getTextureWidth/3;
            sprites[0].setRegion(0, 0, rw, 1.0);
            sprites[1].setRegion(rw, 0, rw*2, 1.0);
            sprites[2].setRegion(rw*2, 0, rw*3, 1.0);
        }
        else
        {
            float rh = sprites[0].getTextureHeight/3;
            sprites[0].setRegion(0, 0, rh, 1.0);
            sprites[1].setRegion(rh, 0, rh*2, 1.0);
            sprites[2].setRegion(rh*2, 0, rh*3, 1.0);
        }
        build();
    }

    protected void updatePosition()
    {
        if(getOrientation == ThreePatchOrientation.horizontal)
        {
            int spWidth = sprites[0].width;
            sprites[0].setPosition(x, y);
            sprites[1].setPosition(x+spWidth, y);
            sprites[2].setPosition(x+width-(spWidth*2), y);
        }
        else
        {
            int spHeight = sprites[0].height;
            sprites[0].setPosition(x, y);
            sprites[1].setPosition(x, y+spHeight);
            sprites[2].setPosition(x, y+height-(spHeight*2));
        }
    }

    void build()
    {
        if(getOrientation == ThreePatchOrientation.horizontal)
        {
            int spWidth = sprites[0].width;
            float xScalingFactor = width-(spWidth*2);
            if(spWidth != 0)
                xScalingFactor/= spWidth;
            else
                xScalingFactor = 0;

            sprites[0].setPosition(x, y);
            sprites[1].setPosition(x+spWidth, y);
            sprites[1].setScale(xScalingFactor, 1);
            sprites[2].setPosition(x+width-(spWidth*2), y);
        }
        else
        {
            int spHeight = sprites[0].height;
            float yScalingFactor = height-(spHeight*2);
            if(spHeight != 0)
                yScalingFactor/= spHeight;
            else
                yScalingFactor = 0;

            sprites[0].setPosition(x, y);
            sprites[1].setPosition(x, y+spHeight);
            sprites[1].setScale(1, yScalingFactor);
            sprites[2].setPosition(x, y+height-(spHeight*2));
        }
    }

    

    void setPosition(int x, int y)
    {
        updatePosition();
    }

    ref HipSpriteVertex[4*3] getVertices(){return vertices;}

}

private ThreePatchOrientation infer(int width, int height){return width > height ? ThreePatchOrientation.horizontal : ThreePatchOrientation.vertical;}


/**
*     0  1  2 
*    ________
*   |________|
*
*
*    ___
*   |   | 0
*   |   | 1
*   |___| 2
*/