/*
* File   : $Source: /alkacon/cvs/opencms/src/com/opencms/template/cache/Attic/CmsElementXml.java,v $
* Date   : $Date: 2001/05/09 12:28:49 $
* Version: $Revision: 1.5 $
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
import com.opencms.boot.*;
import com.opencms.core.*;
import com.opencms.file.*;
import com.opencms.template.*;

/**
 * An instance of CmsElementXML represents an requestable Element in the OpenCms
 * staging-area. It contains all informations to generate the content of this
 * element. It also stores the variants of once generated content to speed up
 * performance.
 *
 * It points to other depending elements. Theses elements are called to generate
 * their content on generation-time.
 *
 * @author Alexander Lucas
 */
public class CmsElementXml extends A_CmsElement implements com.opencms.boot.I_CmsLogChannels {

    /**
     * Constructor for an element with the given class and template name.
     */
    public CmsElementXml(String className, String templateName, CmsCacheDirectives cd) {
        init(className, templateName, cd);
    }

    /**
     * A construcor which creates an element with the given element
     * definitions.
     * @param name the name of this element-definition.
     * @param className the classname of this element-definition.
     * @param cd Cache directives for this element
     * @param defs CmsElementDefinitionCollection for this element.
     */
    public CmsElementXml(String className, String templateName, CmsCacheDirectives cd, CmsElementDefinitionCollection defs) {
        init(className, templateName, cd, defs);
    }

    /**
     * Get the content of this element.
     * @param staging Entry point for the element cache
     * @param cms CmsObject for accessing system resources
     * @param elDefs Definitions of this element's subelements
     * @param parameters All parameters of this request
     * @return Byte array with the processed content of this element.
     * @exception CmsException
     */
    public byte[] getContent(CmsStaging staging, CmsObject cms, CmsElementDefinitionCollection elDefs, String elementName, Hashtable parameters) throws CmsException  {
        long time1 = System.currentTimeMillis();
        byte[] result = null;

        // Merge own element definitions with our parent's definitions
        CmsElementDefinitionCollection mergedElDefs = new CmsElementDefinitionCollection(elDefs, m_elementDefinitions);

        // Get template class.
        // In classic mode, this is donw by the launcher.
        I_CmsTemplate templateClass = null;
        try {
            templateClass = getTemplateClass(cms, m_className);
        } catch(Throwable e) {
            if(CmsBase.isLogging()) {
                CmsBase.log(C_OPENCMS_CRITICAL, toString() + " Could not load my template class \"" + m_className + "\". ");
                CmsBase.log(C_OPENCMS_CRITICAL, e.toString());
                return e.toString().getBytes();
            }
        }

        // Get out own cache directives
        CmsCacheDirectives cd = getCacheDirectives();

        // We really don't want to stream here
        /*boolean streamable = cms.getRequestContext().isStreaming() && cd.isStreamable();
        cms.getRequestContext().setStreaming(streamable);*/
        boolean streamable = false;

        CmsElementVariant variant = null;

        // In classic mode, now the cache-control headers of the response
        // are setted. What shall we do here???

        // Now check, if there is a variant of this element in the cache.
        //if(cacheable && !templateClass.shouldReload(cms, m_templateName, m_elementName, parameters, null)) {
        if(cd.isInternalCacheable()) {
            //variant = getVariant(templateClass.getKey(cms, m_templateName, parameters, null));
            variant = getVariant(cd.getCacheKey(cms, parameters));
            if(variant != null) {
                result = resolveVariant(cms, variant, staging, mergedElDefs, elementName, parameters);
            }
        }
        if(variant == null) {
            // This element was not found in the variant cache.
            // We have to generate it by calling the "classic" getContent() method on the template
            // class.
            try {
                if(cd.isInternalCacheable()) {
                    System.err.println(toString() + " ### Variant not in cache. Must be generated.");
                } else {
                    System.err.println(toString() + " ### Element not cacheable. Generating variant temporarily.");
                }
                // startProcessing() later will be responsible for generating our new variant.
                // since the method resolveVariant (THIS method) will be called recursively
                // by startProcessing(), we have to pass the current element definitions.
                // Unfortunately, there is no other way than putting them into our parameter
                // hashtable. For compatibility reasons we are not allowed to change
                // the interface of getContent() or startProcessing()
                parameters.put("_ELDEFS_", mergedElDefs);
                try {
                    result = templateClass.getContent(cms, m_templateName, elementName, parameters);
                } catch(Exception e) {
                    if(e instanceof CmsException) {
                        CmsException ce = (CmsException)e;
                        if(ce.getType() == ce.C_ACCESS_DENIED) {
                            // This was an access denied exception.
                            // This is not very critical at the moment.
                            if(CmsBase.isLogging()) {
                                CmsBase.log(C_OPENCMS_DEBUG, toString() + " Access denied in getContent for template class " + m_className);
                            }
                        } else {
                            // Any other CmsException.
                            // This could be more critical.
                            if(CmsBase.isLogging()) {
                                CmsBase.log(C_OPENCMS_INFO, toString() + " Error in getContent for template class " + m_className);
                            }
                        }
                        throw ce;
                    } else {
                        // No CmsException. This is really, really bad!
                        if(CmsBase.isLogging()) {
                            CmsBase.log(C_OPENCMS_CRITICAL, toString() + " Non OpenCms error occured in getContent for template class " + m_className);
                        }
                        throw new CmsException(CmsException.C_UNKNOWN_EXCEPTION, e);
                    }
                }
            }
            catch(CmsException e) {
                // Clear cache and do logging here
                throw e;
            }
            if(streamable) {
                result = null;
            }
        }
        long time2 = System.currentTimeMillis();
        System.err.println("% Time for getting content of \"" + elementName + "\": " + (time2 - time1) + " ms");
        return result;
    }
}