/*
* File   : $Source: /alkacon/cvs/opencms/src/com/opencms/template/cache/Attic/CmsElementVariant.java,v $
* Date   : $Date: 2001/05/09 12:28:49 $
* Version: $Revision: 1.2 $
*
* Copyright (C) 2000  The OpenCms Group
*
* This File is part of OpenCms -
* the Open Source Content Mananagement System
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public License
* as published by the Free Software Foundation; either version 2
* of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* For further information about OpenCms, please see the
* OpenCms Website: http://www.opencms.com
*
* You should have received a copy of the GNU General Public License
* long with this program; if not, write to the Free Software
* Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
*/
package com.opencms.template.cache;

import java.util.*;
import java.io.*;
import com.opencms.file.*;

/**
 * An instance of CmsElementVariant stores a single cached variant for an
 * element. This is the generated output (content) of an element. This cache
 * stores all generated strings of this element and all links to other elements.
 *
 * @author Andreas Schouten
 * @author Alexander Lucas
 */
public class CmsElementVariant {

    /**
     * The content of this variant. In this vector object of type String
     * and of CmsElementLink can be stored.
     */
    Vector m_content;

    /**
     * Creates a new empty variant for an element.
     */
    public CmsElementVariant() {
        m_content = new Vector();
    }

    /**
     * Adds static content to this variant.
     * @param staticContent - part of the variant. A peace static content of
     * type string.
     */
    public void add(String staticContent) {
        m_content.add(staticContent);
    }

    /**
     * Adds static content to this variant.
     * @param staticContent - part of the variant. A peace static content of
     * type byte-array.
     */
    public void add(byte[] staticContent) {
        m_content.add(staticContent);
    }

    /**
     * Adds an element-link to this variant.
     * @param elementLink - part of the variant. A link to another element.
     */
    public void add(CmsElementLink elementLink) {
        m_content.add(elementLink);
    }

    /**
     * Get the number of objects in this variant.
     */
    public int size() {
        return m_content.size();
    }

    /**
     * Returns a peace of this variant. It can be of the type String, byte[] or
     * CmsElementLink.
     * @param i - the index to the vector of variant-pieces.
     */
    public Object get(int i) {
        return m_content.get(i);
    }

    /**
     * Get a string representation of this variant.
     * @return String representation.
     */
    public String toString() {
        int len = m_content.size();
        StringBuffer result = new StringBuffer("[CmsElementVariant] (" + len + ") :");
        for(int i=0; i<len; i++) {
            Object o = m_content.elementAt(i);
            String s = o.toString();
            if(o instanceof byte[] || o instanceof String) {
                result.append("TXT");
            } else {
                result.append("(");
                result.append(o.toString());
                result.append(")");
            }
            if(i < len-1) result.append("-");
        }
        return result.toString();
    }
}